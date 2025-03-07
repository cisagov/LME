document.addEventListener('DOMContentLoaded', function() {
    // Find all pre tags
    const preElements = document.querySelectorAll('pre');
    
    preElements.forEach(function(preElement) {
        // Create the copy button
        const copyButton = document.createElement('button');
        copyButton.className = 'copy-button';
        copyButton.setAttribute('aria-label', 'Copy code to clipboard');
        
        // Add clipboard SVG icon
        copyButton.innerHTML = `
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>
                <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>
            </svg>
        `;
        
        // Add the button to the pre tag
        preElement.appendChild(copyButton);
        
        // Add click event
        copyButton.addEventListener('click', function() {
            // Get code text
            const codeElement = preElement.querySelector('code');
            const codeText = codeElement ? codeElement.textContent : preElement.textContent;
            
            // Copy to clipboard
            navigator.clipboard.writeText(codeText)
                .then(function() {
                    // Show check mark icon for success
                    copyButton.innerHTML = `
                        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <polyline points="20 6 9 17 4 12"></polyline>
                        </svg>
                    `;
                    copyButton.classList.add('success');
                    
                    setTimeout(function() {
                        // Revert to clipboard icon
                        copyButton.innerHTML = `
                            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                <rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>
                                <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>
                            </svg>
                        `;
                        copyButton.classList.remove('success');
                    }, 2000);
                })
                .catch(function(err) {
                    console.error('Failed to copy: ', err);
                    // Show error icon
                    copyButton.innerHTML = `
                        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <circle cx="12" cy="12" r="10"></circle>
                            <line x1="15" y1="9" x2="9" y2="15"></line>
                            <line x1="9" y1="9" x2="15" y2="15"></line>
                        </svg>
                    `;
                    copyButton.classList.add('error');
                    
                    setTimeout(function() {
                        // Revert to clipboard icon
                        copyButton.innerHTML = `
                            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                <rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>
                                <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>
                            </svg>
                        `;
                        copyButton.classList.remove('error');
                    }, 2000);
                });
        });
    });
});