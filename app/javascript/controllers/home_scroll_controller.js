const worryBox = document.querySelector('.worry-box');
const worryItems = document.querySelectorAll('.worry-item');

const observer = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {

      worryItems.forEach(item => {
        item.classList.add('is-show');
      });

      observer.unobserve(entry.target);
    }
  });
}, {
  threshold: 0.2
});

observer.observe(worryBox);
