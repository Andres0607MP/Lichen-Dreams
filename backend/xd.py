import urllib.request, json
u='http://127.0.0.1:8000/analysis/results/12'
try:
    with urllib.request.urlopen(u, timeout=10) as r:
        data=json.load(r)
        print('has_imagen_base64', 'imagen_base64' in data or 'image_base64' in data)
        if 'imagen_base64' in data:
            print('len', len(data['imagen_base64']))
        if 'image_base64' in data:
            print('len_image', len(data['image_base64']))
        print('url_imagen:', data.get('url_imagen')[:60])
except Exception as e:
    print('err', e)