const chatForm = document.getElementById('chat-form');
const queryInput = document.getElementById('query-input');
const responseDiv = document.getElementById('response');

chatForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const query = queryInput.value;
    if (!query) return;

    responseDiv.textContent = 'Translating...';

    try {
        const response = await fetch('/chat', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ query }),
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const data = await response.json();

        if (data.error) {
            responseDiv.textContent = `Error: ${data.error}`;
        } else {
            responseDiv.textContent = data.response;
        }

    } catch (error) {
        console.error('Fetch error:', error);
        responseDiv.textContent = 'Failed to get a response from the server.';
    }
});
