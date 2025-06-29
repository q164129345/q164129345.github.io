---
title: 搜索
date: 2025-06-29 23:10:35
type: search
comments: false
---

<style>
.local-search {
  max-width: 800px;
  margin: 0 auto;
  padding: 20px;
}

.local-search-header {
  margin-bottom: 30px;
}

.local-search-input {
  width: 100%;
  padding: 15px 20px;
  font-size: 16px;
  border: 2px solid #e0e0e0;
  border-radius: 8px;
  outline: none;
  transition: border-color 0.3s ease;
}

.local-search-input:focus {
  border-color: #0084ff;
}

.local-search-result {
  margin-top: 20px;
}

.search-result-item {
  padding: 15px;
  margin-bottom: 15px;
  border: 1px solid #f0f0f0;
  border-radius: 8px;
  background: #fafafa;
}

.search-result-title {
  font-size: 18px;
  font-weight: bold;
  margin-bottom: 8px;
}

.search-result-title a {
  color: #333;
  text-decoration: none;
}

.search-result-title a:hover {
  color: #0084ff;
}

.search-result-content {
  color: #666;
  line-height: 1.6;
}

.search-result-highlight {
  background-color: #fff3cd;
  padding: 2px 4px;
  border-radius: 3px;
}
</style>

<script>
document.addEventListener('DOMContentLoaded', function() {
  var searchInput = document.querySelector('.local-search-input');
  var searchResult = document.querySelector('.local-search-result');
  
  if (!searchInput || !searchResult) return;
  
  // 加载搜索数据
  fetch('/search.xml')
    .then(response => response.text())
    .then(data => {
      var parser = new DOMParser();
      var xml = parser.parseFromString(data, 'text/xml');
      var entries = xml.querySelectorAll('entry');
      
      var searchData = [];
      entries.forEach(function(entry) {
        var title = entry.querySelector('title').textContent;
        var content = entry.querySelector('content').textContent;
        var url = entry.querySelector('url').textContent;
        
        searchData.push({
          title: title,
          content: content.replace(/<[^>]+>/g, ''), // 移除HTML标签
          url: url
        });
      });
      
      // 搜索功能
      searchInput.addEventListener('input', function() {
        var keyword = this.value.trim().toLowerCase();
        if (!keyword) {
          searchResult.innerHTML = '';
          return;
        }
        
        var results = searchData.filter(function(item) {
          return item.title.toLowerCase().includes(keyword) || 
                 item.content.toLowerCase().includes(keyword);
        });
        
        if (results.length === 0) {
          searchResult.innerHTML = '<p style="text-align: center; color: #999; padding: 20px;">没有找到相关内容</p>';
          return;
        }
        
        var html = '';
        results.forEach(function(item) {
          var highlightedTitle = item.title.replace(new RegExp(keyword, 'gi'), '<span class="search-result-highlight">$&</span>');
          var contentPreview = item.content.substring(0, 200);
          var highlightedContent = contentPreview.replace(new RegExp(keyword, 'gi'), '<span class="search-result-highlight">$&</span>');
          
          html += '<div class="search-result-item">';
          html += '<div class="search-result-title"><a href="' + item.url + '">' + highlightedTitle + '</a></div>';
          html += '<div class="search-result-content">' + highlightedContent + '...</div>';
          html += '</div>';
        });
        
        searchResult.innerHTML = html;
      });
    })
    .catch(function(error) {
      console.error('搜索数据加载失败:', error);
      searchResult.innerHTML = '<p style="text-align: center; color: #f56565; padding: 20px;">搜索功能暂时不可用</p>';
    });
});
</script>
