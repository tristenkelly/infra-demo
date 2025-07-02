window.addEventListener('DOMContentLoaded', function() {
  fetch('/visit', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      userAgent: navigator.userAgent
    }),
  });
});