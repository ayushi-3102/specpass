// SpecPass MediaPipe Neural Selfie Segmenter for Web
(function() {
  let selfieSegmenter = null;
  let activeCallback = null;

  function getSegmenter() {
    if (selfieSegmenter) return selfieSegmenter;
    if (typeof SelfieSegmentation === 'undefined') {
      console.warn('[SpecPass] SelfieSegmentation library is not loaded');
      return null;
    }
    try {
      selfieSegmenter = new SelfieSegmentation({
        locateFile: (file) => `mediapipe/${file}`
      });
      selfieSegmenter.setOptions({
        modelSelection: 0, // 0 = General (accurate 256x256), 1 = Landscape
      });
      if (typeof selfieSegmenter.initialize === 'function') {
        selfieSegmenter.initialize().catch((e) => {
          console.warn('[SpecPass] MediaPipe pre-warm note:', e);
        });
      }
      console.log('[SpecPass] MediaPipe Selfie Segmentation initialized');
      return selfieSegmenter;
    } catch (e) {
      console.error('[SpecPass] Error initializing MediaPipe:', e);
      return null;
    }
  }

  function ensureInitialized() {
    const seg = getSegmenter();
    if (!seg) return null;
    if (!seg._isConfigured) {
      seg.onResults((results) => {
        if (activeCallback) {
          const cb = activeCallback;
          activeCallback = null;
          cb(results);
        }
      });
      seg._isConfigured = true;
    }
    return seg;
  }

  window.addEventListener('load', () => {
    ensureInitialized();
  });

  window.runMediaPipeSegmentation = function(base64Image) {
    return new Promise((resolve) => {
      try {
        const seg = ensureInitialized();
        if (!seg) {
          resolve(null);
          return;
        }

        const timeout = setTimeout(() => {
          console.warn('[SpecPass] MediaPipe segmentation timed out, using fallback');
          activeCallback = null;
          resolve(null);
        }, 4500);

        activeCallback = (results) => {
          clearTimeout(timeout);
          if (!results || !results.segmentationMask) {
            resolve(null);
            return;
          }
          try {
            const w = 256;
            const h = 256;
            const canvas = document.createElement('canvas');
            canvas.width = w;
            canvas.height = h;
            const ctx = canvas.getContext('2d');
            ctx.drawImage(results.segmentationMask, 0, 0, w, h);
            const imgData = ctx.getImageData(0, 0, w, h);
            const data = imgData.data;
            const confs = [];
            for (let i = 0; i < w * h; i++) {
              confs.push(data[i * 4] / 255.0);
            }
            resolve({
              width: w,
              height: h,
              confidences: confs
            });
          } catch (e) {
            console.error('[SpecPass] Canvas mask extract error:', e);
            resolve(null);
          }
        };

        const img = new Image();
        img.crossOrigin = 'anonymous';
        img.onload = async () => {
          try {
            await seg.send({ image: img });
          } catch (e) {
            console.error('[SpecPass] MediaPipe send error:', e);
            clearTimeout(timeout);
            activeCallback = null;
            resolve(null);
          }
        };
        img.onerror = () => {
          clearTimeout(timeout);
          activeCallback = null;
          resolve(null);
        };
        img.src = base64Image;
      } catch (err) {
        console.error('[SpecPass] runMediaPipeSegmentation error:', err);
        resolve(null);
      }
    });
  };
})();
