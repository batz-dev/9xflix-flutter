import os
import sys
import re
import json
import urllib.parse
import requests
from bs4 import BeautifulSoup
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

def make_proxy_img(u, host_prefix: str):
    if isinstance(u, dict):
        if 'image_url' in u and isinstance(u['image_url'], str):
            u['image_url'] = make_proxy_img(u['image_url'], host_prefix)
        return u
    if not isinstance(u, str) or not u.startswith('http'):
        return u
    if '/api/image-proxy' in u:
        return u
    return f"{host_prefix}/api/image-proxy?url={urllib.parse.quote(u, safe='')}"

def rewrite_movie_images(movie_dict: dict, host_prefix: str):
    if 'poster' in movie_dict and isinstance(movie_dict['poster'], str):
        movie_dict['poster'] = make_proxy_img(movie_dict['poster'], host_prefix)
    if 'screenshots' in movie_dict and isinstance(movie_dict['screenshots'], list):
        movie_dict['screenshots'] = [make_proxy_img(ss, host_prefix) for ss in movie_dict['screenshots']]

@app.route('/api/image-proxy')
def api_image_proxy():
    img_url = request.args.get('url', '').strip()
    if not img_url or not img_url.startswith('http'):
        return "Missing or invalid url", 400

    try:
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Referer': 'https://9xflix.esq/'
        }
        resp = requests.get(img_url, headers=headers, timeout=10)
        if resp.status_code != 200:
            return f"Upstream error {resp.status_code}", 502

        content_type = resp.headers.get('content-type', 'image/jpeg')
        response = app.response_class(
            resp.content,
            status=200,
            mimetype=content_type
        )
        response.headers['Access-Control-Allow-Origin'] = '*'
        response.headers['Cache-Control'] = 'public, max-age=604800'
        return response
    except Exception as e:
        return str(e), 500

@app.route('/api/latest')
def api_latest():
    page = request.args.get('page', 1, type=int)
    data = get_latest_movies(page=page)
    host_prefix = request.host_url.rstrip('/')
    if 'movies' in data:
        for m in data['movies']:
            rewrite_movie_images(m, host_prefix)
    return jsonify(data)

@app.route('/api/search')
def api_search():
    q = request.args.get('q', '').strip()
    page = request.args.get('page', 1, type=int)
    data = search_movies(query=q, page=page)
    host_prefix = request.host_url.rstrip('/')
    if 'movies' in data:
        for m in data['movies']:
            rewrite_movie_images(m, host_prefix)
    return jsonify(data)

@app.route('/api/detail')
def api_detail():
    slug = request.args.get('slug', '').strip()
    data = get_movie_details(slug)
    host_prefix = request.host_url.rstrip('/')
    rewrite_movie_images(data, host_prefix)
    return jsonify(data)

def universal_resolve(intermediate_url: str) -> dict:
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

    clean_url = intermediate_url.strip()

    # 1. Desilinks / Wrapper aggregator handler (Deadpool 2, older movies, collections)
    if 'desilinks' in clean_url:
        try:
            r = s.get(clean_url, headers=headers, timeout=8)
            soup = BeautifulSoup(r.text, 'html.parser')
            target_urls = []
            for a in soup.find_all('a'):
                href = a.get('href', '')
                if any(k in href.lower() for k in ['indishare', 'hubcloud', 'indi-share', 'gofile']):
                    target_urls.append(href)

            # Prioritize indishare, then hubcloud
            target_urls.sort(key=lambda u: 0 if ('indishare' in u or 'indi-share' in u) else 1)
            for t_url in target_urls:
                sub_res = universal_resolve(t_url)
                if sub_res.get('status') == 'success' and sub_res.get('direct_link'):
                    sub_res['intermediate_url'] = intermediate_url
                    return sub_res
        except Exception:
            pass

    # 2. HubCloud handler
    if 'hubcloud' in clean_url:
        try:
            r = s.get(clean_url, headers={'User-Agent': headers['User-Agent'], 'Referer': 'https://desilinks.org/'}, timeout=8)
            soup = BeautifulSoup(r.text, 'html.parser')
            gen_url = None
            for a in soup.find_all('a'):
                href = a.get('href', '')
                if 'gamerxyt.com/hubcloud.php' in href or 'hubcloud.php' in href:
                    gen_url = href
                    break
            if gen_url:
                r_gen = s.get(gen_url, headers={'User-Agent': headers['User-Agent'], 'Referer': clean_url}, timeout=8)
                soup_gen = BeautifulSoup(r_gen.text, 'html.parser')
                for a in soup_gen.find_all('a'):
                    href = a.get('href', '')
                    if 'gpdl.hubcloud.ist' in href:
                        result['status'] = 'success'
                        result['direct_link'] = href
                        result['link_type'] = 'HubCloud 10Gbps Direct CDN'
                        result['mirrors']['r2'] = href
                        result['mirrors']['r2_status'] = 'active'
                        result['mirrors']['hubcloud'] = href
                    elif 'pixeldrain' in href:
                        result['mirrors']['pixeldrain'] = href
                        if not result['direct_link']:
                            result['direct_link'] = href
                            result['link_type'] = 'PixelDrain Direct Mirror'
                if result['direct_link']:
                    result['status'] = 'success'
                    return result
        except Exception:
            pass

    # 3. Indishare Handler (Direct R2 Worker + openDownload mirrors + status API)
    code = clean_url.rstrip('/').split('/')[-1]
    base_indishare = f'https://files.indi-share.com/{code}'
    try:
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
                    r_dl = s.get(dl_page_url, headers={'User-Agent': headers['User-Agent'], 'Referer': base_indishare}, timeout=8)

                    # 3a. Cloudflare R2 worker
                    m_tok = re.search(r'const\s+_r2Token\s*=\s*\"([^\"]+)\"', r_dl.text)
                    m_cod = re.search(r'const\s+_r2Code\s*=\s*\"([^\"]+)\"', r_dl.text)
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

                    # 3b. Extract openDownload mirrors (IndiFiles, GoFile, VikingFile)
                    for m_od in re.finditer(r'openDownload\(\s*[\'\"]([^\'\"]+)[\'\"]', r_dl.text):
                        m_url = m_od.group(1)
                        if 'indi-files' in m_url:
                            result['mirrors']['indifiles'] = m_url
                            if not result['direct_link']:
                                result['direct_link'] = m_url
                                result['link_type'] = 'IndiFiles Direct CDN'
                        elif 'gofile' in m_url:
                            result['mirrors']['gofile'] = m_url
                            if not result['direct_link']:
                                result['direct_link'] = m_url
                                result['link_type'] = 'Gofile Fast Mirror'
                        elif 'vikingfile' in m_url:
                            result['mirrors']['vikingfile'] = m_url
                            if not result['direct_link']:
                                result['direct_link'] = m_url
                                result['link_type'] = 'VikingFile Fast Mirror'
    except Exception:
        pass

    # 4. DriveHub mirror API
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
                        result['drivehub_url'] = drivehub_url
                        for k, v in mirrors.items():
                            result['mirrors'][k] = v
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

    # 5. Status API fallback
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

    # 6. Fallback to original scraper.py resolve
    if not result.get('direct_link'):
        try:
            from scraper import resolve_download_link as orig_resolve
            res_orig = orig_resolve(clean_url)
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
    data = universal_resolve(url)
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
