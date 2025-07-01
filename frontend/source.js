window.addEventListener('DOMContentLoaded', function() {
  fetch('https://o8nn4apsl7.execute-api.us-east-2.amazonaws.com/', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      timestamp: new Date().toISOString(),
      userAgent: navigator.userAgent,
    }),
  });
});
