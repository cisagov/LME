document.addEventListener('DOMContentLoaded', function() {
    let searchIndex = [];
    const searchInput = document.getElementById('searchInput');
    const searchButton = document.getElementById('searchButton');
    const searchResults = document.getElementById('searchResults');
    
    // List of pages to index for search
    const pagesToIndex = [
      'index.html',
      'installation-overview.html',
      'before-you-install.html',
      'architecture.html',
      'installation-prereqs.html',
      'downloading-installing-configuration.html',
      'deploying-agents.html',
      'deploying-agents-elasitc.html',
      'deploying-agents-wazuh.html',
      'installing-sysmon.html',
      'retrieving-passwords.html',
      'starting-and-stoping.html',
      'customizing-lme.html',
      'elast-alert-rule-writing.html',
      'uninstall.html',
      'active-response.html',
      'auditd.html',
      'backups.html',
      'certificates.html',
      'cloud.html',
      'configuration,html',
      'dashboards.html',
      'documentation.html',
      'encryption-at-rest.html',
      'faq.html',
      'filtering.html',
      'index-management.html',
      'log-retention.html',
      'password-encryption.html',
      'security-model.html',
      'sysmon-manual-install.html',
      'troubleshooting.html',
      'upgrading.html',
      'volume-management.html',
      'wazuh-connection.html'
    ];
    
    // Build search index
    function buildSearchIndex() {
      pagesToIndex.forEach(page => {
        fetch(page)
          .then(response => response.text())
          .then(html => {
            const parser = new DOMParser();
            const doc = parser.parseFromString(html, 'text/html');
            
            // Extract title
            const title = doc.querySelector('title')?.textContent || '';
            
            // Extract main content
            const mainContent = doc.querySelector('main')?.textContent || '';
            
            // Add to search index
            searchIndex.push({
              title: title,
              content: mainContent,
              url: page
            });
          })
          .catch(error => console.error(`Error fetching ${page}:`, error));
      });
    }
    
    // Perform search
    function performSearch() {
      const query = searchInput.value.toLowerCase().trim();
      if (query.length < 2) {
        searchResults.innerHTML = '';
        searchResults.style.display = 'none';
        return;
      }
      
      const results = searchIndex.filter(page => 
        page.title.toLowerCase().includes(query) || 
        page.content.includes(query)
      );
      
      displayResults(results, query);
    }
    
    // Display search results
    function displayResults(results, query) {
      if (results.length === 0) {
        searchResults.innerHTML = '<p>No results found</p>';
      } else {
        let resultsHTML = '';
        
        results.forEach(result => {
          // Get a snippet of content around the search term
          const contentLower = result.content;
          const index = contentLower.indexOf(query);
          let snippet = '';
          
          if (index !== -1) {
            const start = Math.max(0, index - 200);
            const end = Math.min(contentLower.length, index + query.length + 200);
            snippet = '...' + contentLower.substring(start, end) + '...';
            // Highlight the search term
            snippet = snippet.replace(new RegExp(query, 'gi'), match => `<mark>${match}</mark>`);
          }
          
          resultsHTML += `
            <div class="search-result-item">
              <a href="${result.url}">${result.title}</a>
              <p>${snippet}</p>
            </div>
          `;
        });
        
        searchResults.innerHTML = resultsHTML;
      }
      
      searchResults.style.display = 'block';
    }
    
    // Event listeners
    searchButton.addEventListener('click', performSearch);
    searchInput.addEventListener('keyup', function(event) {
      if (event.key === 'Enter') {
        performSearch();
      }
      
      // Hide results when input is cleared
      if (searchInput.value.trim() === '') {
        searchResults.innerHTML = '';
        searchResults.style.display = 'none';
      }
    });
    
    // Click outside to close results
    document.addEventListener('click', function(event) {
      if (!event.target.closest('.top-search-container')) {
        searchResults.style.display = 'none';
      }
    });
    
    // Build the index when the page loads
    buildSearchIndex();
  });