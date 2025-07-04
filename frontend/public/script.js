window.addEventListener('DOMContentLoaded', function() {
  fetch('/visit', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      userAgent: navigator.userAgent
    }),
  });
});

document.querySelector('.contact-form').addEventListener('submit', function(event) {
  event.preventDefault();
  const form = event.target;
  const payload = {
  name: form.querySelector('.name').value,
  email: form.querySelector('.email').value,
  message: form.querySelector('.message').value,
};

fetch('/contact', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(payload),
})
.then(response => response.json())
.then(data => {
    if (data.status === 'success') {
      alert('Message sent successfully!');
      form.reset();
    } else {
      alert('Failed to send message.');
    }
  })
  .catch(error => {
    console.error('Error:', error);
    alert('An error occurred while sending your message.');
  });
});