import sys

with open('web/index.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace viewport
content = content.replace(
    '<meta charset="UTF-8">\n  <meta content="IE=Edge" http-equiv="X-UA-Compatible">',
    '<meta charset="UTF-8">\n  <meta content="IE=Edge" http-equiv="X-UA-Compatible">\n  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">'
)
# Update iOS status bar
content = content.replace(
    '<meta name="apple-mobile-web-app-status-bar-style" content="black">',
    '<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">'
)

# Append style before </head>
style_addition = '''
  <style>
    body {
      margin: 0;
      padding: 0;
      overflow: hidden;
      background-color: #0B132B;
      touch-action: none;
    }

    #portrait-warning {
      display: none;
      position: fixed;
      top: 0;
      left: 0;
      width: 100vw;
      height: 100vh;
      background-color: #0B132B;
      color: white;
      z-index: 999999;
      flex-direction: column;
      justify-content: center;
      align-items: center;
      text-align: center;
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    }
    
    @media screen and (orientation: portrait) and (max-width: 900px) {
      #portrait-warning {
        display: flex;
      }
    }
  </style>
</head>
'''
content = content.replace('</head>', style_addition)

# Add body logic
body_addition = '''<body>
  <div id="portrait-warning">
    <div style="font-size: 64px; margin-bottom: 20px;">📱 ➡️ 📺</div>
    <h2>Please Rotate Your Device</h2>
    <p>The game is better when played on landscape.</p>
  </div>

  <script>
    window.addEventListener('pointerdown', function() {
      var docElm = document.documentElement;
      if (!document.fullscreenElement) {
        if (docElm.requestFullscreen) {
          docElm.requestFullscreen();
        } else if (docElm.webkitRequestFullscreen) {
          docElm.webkitRequestFullscreen();
        }
      }
    }, { once: false });
  </script>
'''
content = content.replace('<body>', body_addition)

with open('web/index.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Done")
