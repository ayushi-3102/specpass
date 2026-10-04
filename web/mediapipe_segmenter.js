// SpecPass MediaPipe Neural Selfie Segmenter for Web
(function() {
  let selfieSegmenter = null;

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
      console.log('[SpecPass] MediaPipe Selfie Segmentation initialized');
      return selfieSegmenter;
    } catch (e) {
      console.error('[SpecPass] Error initializing MediaPipe:', e);
      return null;
    }
  }

  window.addEventListener('load', () => {
    getSegmenter();
  });

  window.runMediaPipeSegmentation = function(base64Image) {
    return new Promise((resolve) => {
      try {
        const seg = getSegmenter();
        if (!seg) {
          resolve(null);
          return;
        }

        const img = new Image();
        img.crossOrigin = 'anonymous';
        img.onload = async () => {
          try {
            seg.onResults((results) => {
              if (!results.segmentationMask) {
                resolve(null);
                return;
              }
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
                // MediaPipe outputs segmentation confidence in the Red channel (0 = background, 255 = subject)
                const r = data[i * 4];
                confs.push(r / 255.0);
              }
              resolve({
                width: w,
                height: h,
                confidences: confs
              });
            });

            await seg.send({ image: img });
          } catch (e) {
            console.error('[SpecPass] MediaPipe send error:', e);
            resolve(null);
          }
        };
        img.onerror = () => resolve(null);
        img.src = base64Image;
      } catch (err) {
        console.error('[SpecPass] runMediaPipeSegmentation error:', err);
        resolve(null);
      }
    });
  };
})();
