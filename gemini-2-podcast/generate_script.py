import os
import re
from datetime import datetime
from typing import Optional

from dotenv import load_dotenv

load_dotenv()

# === Set environment variables to suppress warnings ===
os.environ['GRPC_VERBOSITY'] = 'NONE'         # Suppress gRPC logs
os.environ['GLOG_minloglevel'] = '3'         # Suppress glog logs (3 = FATAL)

# === Initialize absl logging to suppress warnings ===
import absl.logging
absl.logging.set_verbosity('error')
absl.logging.use_absl_handler()

# === Import other modules after setting environment variables ===
import google.generativeai as genai
import PyPDF2
import requests
from bs4 import BeautifulSoup
from newspaper import Article, Config
from newspaper.article import ArticleException

NEWS_USER_AGENT = os.getenv("NEWS_USER_AGENT", "gemini-2-podcast/1.0")
NEWS_LANGUAGE_HINT = os.getenv("NEWS_LANGUAGE_HINT", "")
NEWS_REQUEST_TIMEOUT = int(os.getenv("NEWS_REQUEST_TIMEOUT", "15"))

_NEWSPAPER_CONFIG = Config()
_NEWSPAPER_CONFIG.browser_user_agent = NEWS_USER_AGENT
_NEWSPAPER_CONFIG.request_timeout = NEWS_REQUEST_TIMEOUT
_NEWSPAPER_CONFIG.memoize_articles = False
_HTTP_HEADERS = {"User-Agent": NEWS_USER_AGENT}

# === Rest of your code ===
def read_pdf(pdf_path):
    try:
        with open(pdf_path, 'rb') as file:
            reader = PyPDF2.PdfReader(file)
            text = ""
            for page in reader.pages:
                extracted = page.extract_text()
                if extracted:
                    text += extracted
        return text
    except FileNotFoundError:
        print(f"Error: PDF file not found at path: {pdf_path}")
        return ""
    except Exception as e:
        print(f"Error reading PDF file: {str(e)}")
        return ""

def read_md(md_path):
    try:
        with open(md_path, 'r', encoding='utf-8') as file:
            return file.read()
    except FileNotFoundError:
        print(f"Error: Markdown file not found at path: {md_path}")
        return ""
    except Exception as e:
        print(f"Error reading Markdown file: {str(e)}")
        return ""

def _format_publish_date(value) -> Optional[str]:
    if isinstance(value, datetime):
        return value.isoformat()
    if hasattr(value, "isoformat"):
        try:
            return value.isoformat()  # type: ignore[attr-defined]
        except Exception:
            pass
    if value:
        return str(value)
    return None


def _compose_article_payload(article: Article) -> str:
    metadata = []
    if article.title:
        metadata.append(f"Title: {article.title.strip()}")
    publish_date = _format_publish_date(article.publish_date)
    if publish_date:
        metadata.append(f"Published: {publish_date}")
    if article.authors:
        metadata.append(f"Authors: {', '.join(article.authors)}")
    if article.meta_description:
        metadata.append(f"Summary: {article.meta_description.strip()}")
    if getattr(article, "summary", ""):
        metadata.append(f"Key Points: {article.summary.strip()}")

    body = article.text.strip()
    if not body:
        raise ValueError("Article text is empty after parsing")

    metadata_block = "\n".join(metadata).strip()
    return f"{metadata_block}\n\n{body}" if metadata_block else body


def _basic_html_to_text(url: str) -> str:
    try:
        response = requests.get(url, timeout=NEWS_REQUEST_TIMEOUT, headers=_HTTP_HEADERS)
        response.raise_for_status()
        soup = BeautifulSoup(response.text, 'html.parser')
        text = soup.get_text(separator='\n')
        return text.strip()
    except requests.exceptions.RequestException as e:
        print(f"Error accessing URL via fallback: {str(e)}")
        return ""
    except Exception as e:
        print(f"Error processing URL content via fallback: {str(e)}")
        return ""


def read_url(url):
    language = NEWS_LANGUAGE_HINT or None
    try:
        article = Article(url, language=language, config=_NEWSPAPER_CONFIG)
        article.download()
        article.parse()
        try:
            article.nlp()
        except LookupError as nlp_error:
            # NLTK data might be missing; continue without NLP summary.
            print(f"NLTK resource missing for URL {url}: {nlp_error}. Continuing without summary.")
        return _compose_article_payload(article)
    except (ArticleException, ValueError) as article_error:
        print(f"Newspaper4k error for {url}: {article_error}. Falling back to simple scraper.")
    except Exception as article_error:
        print(f"Unexpected Newspaper4k error for {url}: {article_error}. Falling back to simple scraper.")

    return _basic_html_to_text(url)

def read_txt(txt_path):
    try:
        with open(txt_path, 'r', encoding='utf-8') as file:
            return file.read()
    except FileNotFoundError:
        print(f"Error: Text file not found at path: {txt_path}")
        return ""
    except Exception as e:
        print(f"Error reading text file: {str(e)}")
        return ""

def get_content_from_sources():
    sources = []
    content = ""
    
    while True:
        source_type = input("Enter source type (pdf/url/txt/md) or 'done' to finish: ").lower().strip()
        
        if source_type == 'done':
            break
            
        if source_type == "pdf":
            pdf_path = input("Enter PDF file path: ").strip()
            pdf_content = read_pdf(pdf_path)
            if pdf_content:
                content += pdf_content + "\n"
        elif source_type == "url":
            url = input("Enter URL: ").strip()
            url_content = read_url(url)
            if url_content:
                content += url_content + "\n"
        elif source_type == "md":
            md_path = input("Enter Markdown file path: ").strip()
            md_content = read_md(md_path)
            if md_content:
                content += md_content + "\n"
        elif source_type == "txt":
            txt_path = input("Enter text file path: ").strip()
            txt_content = read_txt(txt_path)
            if txt_content:
                content += txt_content + "\n"
        else:
            print("Invalid source type. Please try again.")
            
    return content

def load_prompt_template():
    try:
        with open('system_instructions_script.txt', 'r', encoding='utf-8') as file:
            return file.read()
    except FileNotFoundError:
        raise FileNotFoundError("Prompt template file not found in system_instructions_script.txt")

def create_podcast_script(content):
    try:
        # Initialize Gemini
        genai.configure(api_key=os.getenv('GEMINI_API_KEY'))
        model = genai.GenerativeModel('gemini-2.5-flash')

        # Load prompt template and format with content
        prompt_template = load_prompt_template()
        prompt = f"{prompt_template}\n\nContent: {content}"
        
        response = model.generate_content(prompt)
        return response.text
    except Exception as e:
        print(f"Error generating content: {str(e)}")
        return None
    
def clean_podcast_script(script):
    # Define a regex pattern to identify the start of the podcast text
    podcast_start_pattern = r"^(Speaker A:|Speaker B:)"
    
    # Split the script into lines
    lines = script.splitlines()
    
    # Find the first line that matches the podcast start pattern
    for i, line in enumerate(lines):
        if re.match(podcast_start_pattern, line):
            # Return the script starting from the first podcast line
            return '\n'.join(lines[i:])
    
    # If no match is found, return the original script
    return script

def main():
    # Get content from multiple sources
    content = get_content_from_sources()
    
    # Generate podcast script
    script = create_podcast_script(content)
    if script:
        # Clean the script before saving
        cleaned_script = clean_podcast_script(script)
        
        # Save the cleaned script
        with open("podcast_script.txt", "w", encoding='utf-8') as f:
            f.write(cleaned_script)
        print("Podcast script saved successfully!")

if __name__ == "__main__":
    main()
