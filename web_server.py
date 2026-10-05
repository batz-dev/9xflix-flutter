import os
import sys
from flask import Flask, send_from_directory, request, jsonify

# Add 9xflix to sys.path to access the scraper engine
SYS_9XFLIX = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '9xflix'))
if SYS_9XFLIX not in sys.path:
    sys.path.insert(0, SYS_9XFLIX)

try:
    from scraper import get_latest_movies, search_movies, get_movie_details, resolve_download_link
except ImportError:
    sys.path.insert(0, '/workspaces/my-project/9xflix')
    from scraper import get_latest_movies, search_movies, get_movie_details, resolve_download_link

WEB_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'build', 'web')

app = Flask(__name__, static_folder=None)

@app.after_request
def add_cors_headers(response):
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
    return response

@app.route('/api/latest')
def api_latest():
    page = request.args.get('page', 1, type=int)
    data = get_latest_movies(page=page)
    return jsonify(data)

@app.route('/api/search')
def api_search():
    q = request.args.get('q', '').strip()
    page = request.args.get('page', 1, type=int)
    data = search_movies(query=q, page=page)
    return jsonify(data)

@app.route('/api/detail')
def api_detail():
    slug = request.args.get('slug', '').strip()
    data = get_movie_details(slug)
    return jsonify(data)

@app.route('/api/resolve')
def api_resolve():
    url = request.args.get('url', '').strip()
    data = resolve_download_link(url)
    return jsonify(data)

# Catch-all to serve Flutter Web SPA and its static assets
@app.route('/', defaults={'path': ''})
@app.route('/<path:path>')
def serve_flutter(path):
    if path != "" and os.path.exists(os.path.join(WEB_DIR, path)):
        return send_from_directory(WEB_DIR, path)
    return send_from_directory(WEB_DIR, 'index.html')

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    print(f"Serving Flutter Web with 9xflix APIs on port {port}...")
    app.run(host='0.0.0.0', port=port, debug=False)
