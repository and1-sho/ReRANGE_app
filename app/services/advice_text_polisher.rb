require "json"

class AdviceTextPolisher
  class PolishError < StandardError; end

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
    { body: polished_body }
  rescue OpenAI::Error => e
    raise PolishError, "AIによる整形に失敗しました。時間をおいて再試行してください。"
  rescue JSON::ParserError, TypeError, KeyError
    raise PolishError, "AIからの応答が不正です。時間をおいて再試行してください。"
  end

  private

  def system_prompt
    <<~PROMPT
      あなたはトレーナーの文章を、メンバーに伝わりやすいアドバイス文へ整えるアシスタントです。
      必ず丁寧語（です/ます調）で出力してください。
      文体は礼儀を保ちつつ、硬すぎない自然な会話調にしてください。
      「幸いです」「ご教示」など過度にかしこまった語は避け、必要な場面だけ使ってください。
      事実関係や意図は変えず、誇張・創作は禁止です。
      表現が強い場合は、意味を保ったまま丁寧な言葉に言い換えてください。
      本文は自然文を基本にし、手順や論点整理が有効な場合のみ箇条書きを使ってください。
      出力はJSONのみ。必ず "body" キー1つだけを返してください。
    PROMPT
  end

  def user_prompt
    <<~PROMPT
      以下の本文を整えてください。
      #{@body}
    PROMPT
  end

  def parse_response(response)
    content = response.dig("choices", 0, "message", "content")
    raise KeyError if content.blank?

    JSON.parse(content)
  end

  def normalize_body(text)
    normalized = text.to_s.strip
    raise PolishError, "本文の整形に失敗しました。入力内容を見直してください。" if normalized.blank?

    normalized
  end
end
