import Foundation

extension WebServerManager {
    func getWebInterfaceHTML() -> String {
        return """
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>JustSync - 照片管理</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: #f5f5f7;
            color: #1d1d1f;
        }
        
        .header {
            background: white;
            padding: 20px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            position: sticky;
            top: 0;
            z-index: 100;
        }
        
        .header-content {
            max-width: 1400px;
            margin: 0 auto;
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 15px;
        }
        
        h1 {
            font-size: 28px;
            font-weight: 600;
        }
        
        .controls {
            display: flex;
            gap: 12px;
            align-items: center;
        }
        
        .btn {
            padding: 10px 20px;
            border: none;
            border-radius: 8px;
            font-size: 14px;
            font-weight: 500;
            cursor: pointer;
            transition: all 0.2s;
            display: inline-flex;
            align-items: center;
            gap: 6px;
        }
        
        .btn:hover {
            transform: translateY(-1px);
            box-shadow: 0 4px 12px rgba(0,0,0,0.15);
        }
        
        .btn-primary {
            background: #007AFF;
            color: white;
        }
        
        .btn-danger {
            background: #FF3B30;
            color: white;
        }
        
        .btn-success {
            background: #34C759;
            color: white;
        }
        
        .btn-secondary {
            background: #8E8E93;
            color: white;
        }
        
        .btn:disabled {
            opacity: 0.5;
            cursor: not-allowed;
        }
        
        .stats {
            display: flex;
            gap: 20px;
            font-size: 14px;
            color: #6e6e73;
        }
        
        .stat-item {
            display: flex;
            align-items: center;
            gap: 6px;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 20px;
        }
        
        .gallery {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
            gap: 15px;
        }
        
        .photo-item {
            position: relative;
            aspect-ratio: 1;
            border-radius: 12px;
            overflow: hidden;
            cursor: pointer;
            transition: all 0.2s;
            background: white;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        
        .photo-item:hover {
            transform: translateY(-4px);
            box-shadow: 0 8px 24px rgba(0,0,0,0.15);
        }
        
        .photo-item.selected {
            border: 3px solid #007AFF;
        }
        
        .photo-item img {
            width: 100%;
            height: 100%;
            object-fit: cover;
        }
        
        .photo-checkbox {
            position: absolute;
            top: 10px;
            right: 10px;
            width: 24px;
            height: 24px;
            background: white;
            border: 2px solid #007AFF;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            opacity: 0;
            transition: opacity 0.2s;
        }
        
        .selection-mode-active .photo-checkbox {
            opacity: 1;
        }
        
        .photo-item.selected .photo-checkbox {
            opacity: 1;
            background: #007AFF;
        }
        
        .photo-checkbox::after {
            content: '✓';
            color: white;
            font-size: 14px;
            display: none;
        }
        
        .photo-item.selected .photo-checkbox::after {
            display: block;
        }
        
        .photo-info {
            position: absolute;
            bottom: 0;
            left: 0;
            right: 0;
            padding: 8px;
            background: linear-gradient(to top, rgba(0,0,0,0.7), transparent);
            color: white;
            font-size: 12px;
        }
        
        .badge {
            display: inline-block;
            padding: 2px 6px;
            background: rgba(255,255,255,0.3);
            border-radius: 4px;
            font-size: 10px;
            margin-right: 4px;
        }
        
        .loading {
            text-align: center;
            padding: 40px;
            color: #6e6e73;
        }
        
        .spinner {
            border: 3px solid #f3f3f3;
            border-top: 3px solid #007AFF;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
            margin: 0 auto 15px;
        }
        
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        
        .modal {
            display: none;
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(0,0,0,0.9);
            z-index: 1000;
            align-items: center;
            justify-content: center;
        }
        
        .modal.active {
            display: flex;
        }
        
        .modal-content {
            max-width: 90vw;
            max-height: 90vh;
            position: relative;
        }
        
        .modal-content img, .modal-content video {
            max-width: 100%;
            max-height: 90vh;
            object-fit: contain;
        }
        
        .modal-close {
            position: absolute;
            top: 20px;
            right: 20px;
            background: white;
            border: none;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            font-size: 24px;
            cursor: pointer;
            z-index: 1001;
        }
        
        .progress-bar {
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            height: 3px;
            background: #007AFF;
            transform: scaleX(0);
            transform-origin: left;
            transition: transform 0.3s;
            z-index: 1001;
        }
        
        @media (max-width: 768px) {
            .gallery {
                grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
                gap: 10px;
            }
            
            .header-content {
                flex-direction: column;
                align-items: flex-start;
            }
            
            .controls {
                width: 100%;
                flex-wrap: wrap;
            }
        }

        /* 下载提示 Toast 样式 */
        .download-toast {
            position: fixed;
            bottom: 30px;
            right: 30px;
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            -webkit-backdrop-filter: blur(10px);
            border: 1px solid rgba(0, 0, 0, 0.1);
            border-radius: 12px;
            padding: 16px 20px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.15);
            z-index: 2000;
            display: none;
            flex-direction: column;
            gap: 10px;
            width: 280px;
            transition: all 0.3s ease;
        }
        
        .download-toast.active {
            display: flex;
        }
        
        .download-toast-content {
            display: flex;
            align-items: center;
            gap: 12px;
        }
        
        .download-toast-spinner {
            border: 2px solid #f3f3f3;
            border-top: 2px solid #007AFF;
            border-radius: 50%;
            width: 18px;
            height: 18px;
            animation: spin 0.8s linear infinite;
        }
        
        .download-toast-text {
            font-size: 14px;
            font-weight: 500;
            color: #1d1d1f;
        }
        
        .download-toast-progress-bg {
            width: 100%;
            height: 6px;
            background: #e5e5ea;
            border-radius: 3px;
            overflow: hidden;
        }
        
        .download-toast-progress-bar {
            width: 100%;
            height: 100%;
            background: #007AFF;
            transform: scaleX(0);
            transform-origin: left;
            transition: transform 0.2s ease;
        }
        
        .download-toast.success {
            background: #34C759;
            border-color: #34C759;
        }
        
        .download-toast.success .download-toast-text {
            color: white;
        }
        
        .download-toast.success .download-toast-spinner {
            display: none;
        }
        
        .download-toast.success .download-toast-progress-bg {
            display: none;
        }
    </style>
</head>
<body>
    <div class="progress-bar" id="progressBar"></div>
    
    <!-- 下载提示 Toast -->
    <div class="download-toast" id="downloadToast">
        <div class="download-toast-content">
            <div class="download-toast-spinner"></div>
            <div class="download-toast-text" id="downloadToastText">正在准备下载...</div>
        </div>
        <div class="download-toast-progress-bg">
            <div class="download-toast-progress-bar" id="downloadToastBar"></div>
        </div>
    </div>
    
    <div class="header">
        <div class="header-content">
            <h1>📱 JustSync</h1>
            <div class="stats">
                <div class="stat-item">
                    <span>📷 总数:</span>
                    <strong id="totalCount">0</strong>
                </div>
                <div class="stat-item">
                    <span>✅ 已选:</span>
                    <strong id="selectedCount">0</strong>
                </div>
            </div>
            <div class="controls">
                <button class="btn btn-primary" onclick="toggleSelectionMode()" id="selectionBtn">
                    选择模式
                </button>
                <button class="btn btn-success" onclick="downloadSelected()" id="downloadBtn" disabled>
                    下载选中
                </button>
                <button class="btn btn-danger" onclick="deleteSelected()" id="deleteBtn" disabled>
                    删除选中
                </button>
                <button class="btn btn-secondary" onclick="loadPhotos()">
                    刷新
                </button>
            </div>
        </div>
    </div>
    
    <div class="container">
        <div class="loading" id="loading">
            <div class="spinner"></div>
            <div>加载照片中...</div>
        </div>
        <div class="gallery" id="gallery"></div>
    </div>
    
    <div class="modal" id="modal">
        <button class="modal-close" onclick="closeModal()">×</button>
        <div class="modal-content" id="modalContent"></div>
    </div>
    
    <script>
        let photos = [];
        let selectedPhotos = new Set();
        let selectionMode = false;
        
        async function loadPhotos() {
            document.getElementById('loading').style.display = 'block';
            document.getElementById('gallery').innerHTML = '';
            
            try {
                const response = await fetch('/api/photos');
                const data = await response.json();
                photos = data.photos;
                
                document.getElementById('totalCount').textContent = photos.length;
                renderGallery();
            } catch (error) {
                console.error('Failed to load photos:', error);
                alert('加载照片失败');
            } finally {
                document.getElementById('loading').style.display = 'none';
            }
        }
        
        function getPhotoFilename(photo) {
            const timestamp = photo.creationDate ? new Date(photo.creationDate * 1000).toISOString().replace(/[:.]/g, '-').slice(0, 19) : Date.now();
            const extension = photo.mediaType === 'video' ? 'mp4' : 'jpg';
            return `IMG_${timestamp}.${extension}`;
        }
        
        function renderGallery() {
            const gallery = document.getElementById('gallery');
            gallery.innerHTML = '';
            gallery.className = 'gallery' + (selectionMode ? ' selection-mode-active' : '');
            
            photos.forEach(photo => {
                const item = document.createElement('div');
                item.className = 'photo-item' + (selectedPhotos.has(photo.identifier) ? ' selected' : '');
                item.onclick = () => handlePhotoClick(photo);
                
                const img = document.createElement('img');
                img.src = `/api/thumbnail/${photo.identifier}`;
                img.alt = 'Photo';
                img.loading = 'lazy';
                
                const checkbox = document.createElement('div');
                checkbox.className = 'photo-checkbox';
                
                const info = document.createElement('div');
                info.className = 'photo-info';
                
                let badges = '';
                if (photo.mediaType === 'video') badges += '<span class="badge">🎥 视频</span>';
                if (photo.subtypes) {
                    if (photo.subtypes.includes('portrait')) badges += '<span class="badge">👤 人像</span>';
                    if (photo.subtypes.includes('live')) badges += '<span class="badge">⚡ Live</span>';
                    if (photo.subtypes.includes('panorama')) badges += '<span class="badge">🌄 全景</span>';
                }
                if (photo.location) badges += '<span class="badge">📍 GPS</span>';
                
                info.innerHTML = badges;
                
                item.appendChild(img);
                item.appendChild(checkbox);
                item.appendChild(info);
                gallery.appendChild(item);
            });
            
            // 更新选择模式按钮状态
            const btn = document.getElementById('selectionBtn');
            btn.textContent = selectionMode ? '取消选择' : '选择模式';
        }
        
        function handlePhotoClick(photo) {
            if (selectionMode) {
                if (selectedPhotos.has(photo.identifier)) {
                    selectedPhotos.delete(photo.identifier);
                } else {
                    selectedPhotos.add(photo.identifier);
                }
                document.getElementById('selectedCount').textContent = selectedPhotos.size;
                document.getElementById('downloadBtn').disabled = selectedPhotos.size === 0;
                document.getElementById('deleteBtn').disabled = selectedPhotos.size === 0;
                renderGallery();
            } else {
                openModal(photo);
            }
        }
        
        function toggleSelectionMode() {
            selectionMode = !selectionMode;
            const btn = document.getElementById('selectionBtn');
            btn.textContent = selectionMode ? '取消选择' : '选择模式';
            
            if (!selectionMode) {
                selectedPhotos.clear();
                document.getElementById('selectedCount').textContent = '0';
                document.getElementById('downloadBtn').disabled = true;
                document.getElementById('deleteBtn').disabled = true;
            }
            
            renderGallery();
        }
        
        async function downloadSelected() {
            const progressBar = document.getElementById('progressBar');
            const toast = document.getElementById('downloadToast');
            const toastText = document.getElementById('downloadToastText');
            const toastBar = document.getElementById('downloadToastBar');
            
            const identifiers = Array.from(selectedPhotos);
            const total = identifiers.length;
            let completed = 0;
            
            progressBar.style.transform = 'scaleX(0)';
            toast.className = 'download-toast active';
            toastText.textContent = `正在准备下载...`;
            toastBar.style.transform = 'scaleX(0)';
            
            for (const identifier of identifiers) {
                try {
                    const photo = photos.find(p => p.identifier === identifier);
                    const response = await fetch(`/api/photo/${identifier}`);
                    const blob = await response.blob();
                    
                    const url = window.URL.createObjectURL(blob);
                    const a = document.createElement('a');
                    a.href = url;
                    a.download = getPhotoFilename(photo);
                    document.body.appendChild(a);
                    a.click();
                    document.body.removeChild(a);
                    window.URL.revokeObjectURL(url);
                    
                    completed++;
                    const progress = completed / total;
                    progressBar.style.transform = `scaleX(${progress})`;
                    toastBar.style.transform = `scaleX(${progress})`;
                    toastText.textContent = `正在下载: ${completed} / ${total}`;
                    
                    // 添加小延迟以确保浏览器能处理多个下载
                    await new Promise(resolve => setTimeout(resolve, 200));
                } catch (error) {
                    console.error('Download failed:', error);
                }
            }
            
            // 显示下载完成状态
            toast.className = 'download-toast active success';
            toastText.textContent = `🎉 成功下载 ${total} 个文件!`;
            
            setTimeout(() => {
                progressBar.style.transform = 'scaleX(0)';
                toast.className = 'download-toast';
            }, 3000);
        }
        
        async function deleteSelected() {
            if (!confirm(`确定要删除 ${selectedPhotos.size} 张照片吗？此操作不可恢复！`)) {
                return;
            }
            
            try {
                const response = await fetch('/api/delete', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        identifiers: Array.from(selectedPhotos)
                    })
                });
                
                if (response.ok) {
                    alert('删除成功');
                    selectedPhotos.clear();
                    toggleSelectionMode();
                    await loadPhotos();
                } else {
                    alert('删除失败');
                }
            } catch (error) {
                console.error('Delete failed:', error);
                alert('删除失败');
            }
        }
        
        function openModal(photo) {
            const modal = document.getElementById('modal');
            const modalContent = document.getElementById('modalContent');
            modalContent.innerHTML = '';
            
            if (photo.mediaType === 'video') {
                const video = document.createElement('video');
                video.src = `/api/photo/${photo.identifier}`;
                video.controls = true;
                video.autoplay = true;
                modalContent.appendChild(video);
            } else {
                const img = document.createElement('img');
                img.src = `/api/photo/${photo.identifier}`;
                modalContent.appendChild(img);
            }
            
            modal.classList.add('active');
        }
        
        function closeModal() {
            const modal = document.getElementById('modal');
            modal.classList.remove('active');
            document.getElementById('modalContent').innerHTML = '';
        }
        
        document.getElementById('modal').onclick = function(e) {
            if (e.target === this) {
                closeModal();
            }
        };
        
        window.onload = loadPhotos;
    </script>
</body>
</html>
"""
    }
}
