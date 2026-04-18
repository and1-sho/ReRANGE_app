require "json"

class RequestTextPolisher
  class PolishError < StandardError; end

  TITLE_MAX_LENGTH = 24

  def initialize(body:)
    @body = body.to_s.strip
    @client = OpenAI::Client.new(access_token: ENV.fetch("OPENAI_API_KEY"))
  end

  def call
    raise PolishError, "本文を入力してください" if @body.blank?

    response = @client.chat(
      parameters: {
        model: ENV.fetch("OPENAI_MODEL", "gpt-4o-mini"),
        temperature: 0.4,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: user_prompt }
        ]
      }
    )

    parsed = parse_response(response)
    polished_body = normalize_body(parsed["body"])
    title_base = generate_title_base_from_body(polished_body, fallback: parsed["title"])
    title = format_title(title_base)
    { title: title, body: polished_body }
  rescue OpenAI::Error => e
    raise PolishError, "AIによる整形に失敗しました。時間をおいて再試行してください。"
  rescue JSON::ParserError, TypeError, KeyError
    raise PolishError, "AIからの応答が不正です。時間をおいて再試行してください。"
  end

  private

  def system_prompt
    <<~PROMPT
      あなたはメンバーの文章を、トレーナーに伝わりやすいリクエスト文へ整えるアシスタントです。
      必ず丁寧語（です/ます調）で出力してください。
      文体は礼儀を保ちつつ、硬すぎない自然な会話調にしてください。
      「幸いです」「ご教示」「お伺い」など過度にかしこまった語は避け、必要な場面だけ使ってください。
      事実関係や意図は変えず、誇張・創作は禁止です。
      表現が強い場合は、意味を保ったまま丁寧な言葉に言い換えてください。
      本文は自然文を基本にし、手順や論点整理が有効な場合のみ箇条書きを使ってください。
      出力はJSONのみ。必ず "title" と "body" の2キーを返してください。
      title は本文の要点（悩み・目的・知りたいこと）を反映したキーワード句にしてください。
      title の末尾に「について」は付けないでください（アプリ側で付与します）。
      title は途中で切れた不自然な表現を避け、助詞で終えないでください（例: 「〜のお」「〜の」禁止）。
      title に「教えてください」「相談です」などの冗長表現は入れないでください。
    PROMPT
  end

  def user_prompt
    <<~PROMPT
      以下の本文を整えてください。
      #{body}
    PROMPT
  end

  attr_reader :body

  def parse_response(response)
    content = response.dig("choices", 0, "message", "content")
    raise KeyError if content.blank?

    JSON.parse(content)
  end

  def normalize_title(title)
    normalized = title.to_s.strip
    normalized = "リクエスト" if normalized.blank?
    normalized = normalized.gsub(/[。．！？!?\s]+$/, "")
    normalized = normalized.gsub(/(について|の相談|相談です|相談|を教えてください|教えてください)\z/, "")
    normalized = normalized.gsub(/(している|してる|してい|して|する|した)\z/, "")
    normalized = normalized.strip
    normalized = normalized.gsub(/(の|と|や|を|に|へ|が|は|で|も|お)\z/, "")
    normalized.present? ? normalized : "リクエスト"
  end

  def generate_title_base_from_body(polished_body, fallback:)
    response = @client.chat(
      parameters: {
        model: ENV.fetch("OPENAI_MODEL", "gpt-4o-mini"),
        temperature: 0.2,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: title_base_prompt },
          { role: "user", content: "本文:\n#{polished_body}" }
        ]
      }
    )

    parsed = parse_response(response)
    candidate = normalize_title(parsed["title_base"])
    candidate = squeeze_title_base(candidate)
    return candidate unless low_quality_title?(candidate)

    heuristic_title_from_body(polished_body, fallback)
  rescue OpenAI::Error, JSON::ParserError, TypeError, KeyError
    heuristic_title_from_body(polished_body, fallback)
  end

  def heuristic_title_from_body(polished_body, fallback)
    candidate = polished_body.to_s.split(/[\n。]/).find(&:present?).to_s
    candidate = candidate.gsub(/^・+/, "").strip
    candidate = candidate.gsub(/(と考えております|と考えています|と思っています|と思います).*\z/, "")
    candidate = candidate.gsub(/(教えてください|ご指導ください|お願いします).*\z/, "")
    candidate = candidate.tr("　", " ").gsub(/\s+/, "")
    candidate = normalize_title(candidate)
    candidate = squeeze_title_base(candidate)
    candidate = normalize_title(fallback) if low_quality_title?(candidate)
    candidate = squeeze_title_base(candidate)
    low_quality_title?(candidate) ? "リクエスト" : candidate
  end

  def low_quality_title?(title)
    return true if title.blank? || title.length < 4

    title.match?(/[\p{Hiragana}][\p{Han}]\z/) ||
      title.match?(/の[\p{Han}\p{Hiragana}\p{Katakana}]?\z/) ||
      title.match?(/(相|練|戦|時)\z/)
  end

  def title_base_prompt
    <<~PROMPT
      あなたは本文からタイトルの「主題語句」だけを作るアシスタントです。
      出力はJSONのみ。必ず "title_base" キーを返してください。
      条件:
      - 20文字以内
      - 途中で切れた不自然な表現を禁止
      - 語尾を助詞で終えない（例: 「〜の」「〜に」禁止）
      - 「〜について」「教えてください」などの定型句は禁止
      - 相談の主題が一目で分かる語句にする
    PROMPT
  end

  def squeeze_title_base(base)
    candidate = normalize_title(base)
    return candidate if candidate.length <= (TITLE_MAX_LENGTH - 4)

    refined = shorten_title_with_ai(candidate)
    refined = normalize_title(refined)
    return refined if refined.length <= (TITLE_MAX_LENGTH - 4) && !low_quality_title?(refined)

    hard_limit_title(candidate)
  end

  def shorten_title_with_ai(base)
    response = @client.chat(
      parameters: {
        model: ENV.fetch("OPENAI_MODEL", "gpt-4o-mini"),
        temperature: 0.1,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: title_shorten_prompt },
          { role: "user", content: "主題語句:\n#{base}" }
        ]
      }
    )
    parsed = parse_response(response)
    parsed["title_base"].to_s
  rescue OpenAI::Error, JSON::ParserError, TypeError, KeyError
    base
  end

  def title_shorten_prompt
    <<~PROMPT
      あなたは日本語タイトルを短く自然に整えるアシスタントです。
      出力はJSONのみ。必ず "title_base" キーを返してください。
      条件:
      - 20文字以内
      - 途中で切れた不自然な語を作らない
      - 意味の核（何についての相談か）を残す
      - 語尾を助詞で終えない
      - 「について」「相談」などは付けない
    PROMPT
  end

  def hard_limit_title(base)
    limited = base.mb_chars.limit(TITLE_MAX_LENGTH - 4).to_s
    limited = limited.gsub(/(している|してる|してい|して|する|した)\z/, "")
    limited = limited.gsub(/(の|と|や|を|に|へ|が|は|で|も|お|相|練|戦|時)\z/, "")
    limited.present? ? limited : "リクエスト"
  end

  def format_title(base_title)
    base = normalize_title(base_title)
    base = squeeze_title_base(base)
    base = "リクエスト" if base.blank?
    "#{base}について"
  end

  def normalize_body(text)
    normalized = text.to_s.strip
    raise PolishError, "本文の整形に失敗しました。入力内容を見直してください。" if normalized.blank?

    normalized
  end
end
