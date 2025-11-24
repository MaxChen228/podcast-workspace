import sys
import os

# Add the parent directory to sys.path so we can import the module
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../..')))

from server.app.services.news_service import NewsService

print("Checking NewsService...")
if hasattr(NewsService, 'fetch_article_content'):
    print("SUCCESS: NewsService has fetch_article_content method")
else:
    print("FAILURE: NewsService does NOT have fetch_article_content method")
    print("Dir:", dir(NewsService))
