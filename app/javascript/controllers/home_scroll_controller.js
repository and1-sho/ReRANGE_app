const worryBox = document.querySelector('.worry-box');
const worryItems = document.querySelectorAll('.worry-item');

let rootMarginValue = '-10% 0px';

if (window.innerWidth < 640) {
  // SP
  rootMarginValue = '-45% 0px';
} else if (window.innerWidth < 1024) {
  // TB
  rootMarginValue = '-46% 0px';
} else {
  // PC
  rootMarginValue = '-46% 0px';
}

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
  threshold: 0,
  rootMargin: rootMarginValue
});

observer.observe(worryBox);
