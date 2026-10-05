import os
import sys
import re
import json
import requests
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

def smart_resolve_download_link(intermediate_url: str) -> dict:
    code = intermediate_url.rstrip('/').split('/')[-1]
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': 'https://9xflix.esq/'
    }
    s = requests.Session()

    result = {
        'status': 'error',
        'intermediate_url': intermediate_url,
        'direct_link': None,
        'mirrors': {},
        'link_type': None,
        'file_name': '',
        'error': None
    }

    # Tier 1: Indishare Direct Cloudflare R2 Worker (/token -> /api/r2link)
    try:
        base_indishare = f'https://files.indi-share.com/{code}'
        r_page = s.get(base_indishare, headers=headers, timeout=8)
        if r_page.status_code == 200:
            m_title = re.search(r'<title>\s*(.*?)\s*—\s*Indishare</title>', r_page.text)
            if m_title:
                result['file_name'] = m_title.group(1).strip()

            r_token = s.post(f'{base_indishare}/token', headers={
                'User-Agent': headers['User-Agent'],
                'Referer': base_indishare,
                'Content-Type': 'application/x-www-form-urlencoded',
                'X-Requested-With': 'XMLHttpRequest'
            }, timeout=8)

            if r_token.status_code == 200:
                token_data = r_token.json()
                if token_data.get('status') == 'success' and token_data.get('url'):
                    dl_page_url = token_data['url']
                    r_dl_page = s.get(dl_page_url, headers={'User-Agent': headers['User-Agent'], 'Referer': base_indishare}, timeout=8)
                    m_tok = re.search(r'const\s+_r2Token\s*=\s*\"([^\"]+)\"', r_dl_page.text)
                    m_cod = re.search(r'const\s+_r2Code\s*=\s*\"([^\"]+)\"', r_dl_page.text)
                    if m_tok and m_cod:
                        r_r2 = s.post('https://files.indi-share.com/api/r2link', json={
                            'code': m_cod.group(1),
                            'token': m_tok.group(1)
                        }, headers={
                            'User-Agent': headers['User-Agent'],
                            'Referer': dl_page_url,
                            'Content-Type': 'application/json'
                        }, timeout=8)
                        if r_r2.status_code == 200:
                            r2_data = r_r2.json()
                            if r2_data.get('status') == 'success' and r2_data.get('url'):
                                result['status'] = 'success'
                                result['direct_link'] = r2_data['url']
                                result['link_type'] = 'Cloudflare R2 Direct Worker'
                                result['mirrors']['r2'] = r2_data['url']
                                result['mirrors']['r2_status'] = 'active'
    except Exception as e:
        pass

    # Tier 2: Indishare DriveHub mirror API
    if not result.get('direct_link'):
        try:
            mirror_api = f'https://files.indi-share.com/api/mirror-link?code={code}&service=drivehub'
            r_mirror = s.get(mirror_api, headers={'User-Agent': headers['User-Agent'], 'Referer': f'https://files.indi-share.com/{code}'}, timeout=8)
            if r_mirror.status_code == 200:
                m_data = r_mirror.json()
                if m_data.get('status') == 'success' and m_data.get('url'):
                    drivehub_url = m_data['url']
                    file_id = drivehub_url.rstrip('/').split('/')[-1]
                    status_api = f'https://new1.drivehub.dad/system/ajax/mirror-status.php?id={file_id}'
                    r_status = s.get(status_api, headers={'User-Agent': headers['User-Agent'], 'Referer': drivehub_url}, timeout=8)
                    if r_status.status_code == 200:
                        mirrors = r_status.json()
                        result['status'] = 'success'
                        result['drivehub_url'] = drivehub_url
                        result['mirrors'] = mirrors
                        if mirrors.get('r2') and mirrors.get('r2_status') == 'active':
                            result['direct_link'] = mirrors['r2']
                            result['link_type'] = 'Cloudflare R2 Direct High-Speed'
                        elif mirrors.get('gofile'):
                            result['direct_link'] = mirrors['gofile']
                            result['link_type'] = 'Gofile Fast Mirror'
                        elif mirrors.get('vikingfile'):
                            result['direct_link'] = mirrors['vikingfile']
                            result['link_type'] = 'VikingFile Fast Mirror'
        except Exception:
            pass

    # Tier 3: Indishare Status API for GoFile / SendNow / R2
    if not result.get('direct_link'):
        try:
            r_st = s.get(f'https://files.indi-share.com/api/status?code={code}', headers=headers, timeout=6)
            if r_st.status_code == 200:
                st_data = r_st.json()
                if st_data.get('file_name'):
                    result['file_name'] = st_data['file_name']
                hosts = st_data.get('hosts', {})
                for h_name, h_info in hosts.items():
                    if h_info.get('download_url'):
                        result['mirrors'][h_name] = h_info['download_url']
                        if not result['direct_link']:
                            result['direct_link'] = h_info['download_url']
                            result['link_type'] = f'{h_name.upper()} Mirror'
        except Exception:
            pass

    # Tier 4: Fallback to original resolve_download_link
    if not result.get('direct_link'):
        try:
            res_orig = resolve_download_link(intermediate_url)
            if res_orig.get('status') == 'success' and res_orig.get('direct_link'):
                return res_orig
        except Exception:
            pass

    if result.get('direct_link'):
        result['status'] = 'success'
        result['error'] = None
    else:
        result['status'] = 'error'
        result['error'] = 'Could not automatically bypass mirror. File might be currently syncing.'

    return result

@app.route('/api/resolve')
def api_resolve():
    url = request.args.get('url', '').strip()
    data = smart_resolve_download_link(url)
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
