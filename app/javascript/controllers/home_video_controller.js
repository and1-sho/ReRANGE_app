import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const videos = this.element.querySelectorAll('video');

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          const video = entry.target;

          if (entry.isIntersecting) {
            video.play();
          } else {
            video.pause();
          }
        });
      },
      {
        threshold: 0.5 // 50%見えたら再生
      }
    );

    videos.forEach((video) => observer.observe(video));
  }
}