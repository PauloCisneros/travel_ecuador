import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/app_theme.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = _buildController();
  }

  WebViewController _buildController() {
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            debugPrint('EcuGuía: página cargada');
          },
          onWebResourceError: (error) {
            debugPrint('EcuGuía ERROR: ${error.errorCode} - ${error.description}');
          },
        ),
      )
      ..addJavaScriptChannel('BotpressBridge', onMessageReceived: (message) {
        if (message.message == 'ready' && mounted) {
          setState(() => _isLoading = false);
        }
        if (message.message == 'closed' && mounted) {
          Navigator.pop(context);
        }
      })
      ..loadHtmlString(_buildHtml(), baseUrl: 'https://cdn.botpress.cloud');
  }

  String _buildHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
  <style>
    html, body {
      margin: 0; padding: 0; height: 100%; overflow: hidden;
      background: #FBF9F6;
    }
    #webchat-container {
      position: relative; width: 100%; height: 100%;
    }
    .bpFab, .bp-widget-launcher, .bpWidget, .bp-launcher,
    [class*="floating"], [class*="launcher"], [id*="botpress"],
    [data-testid*="launcher"] {
      display: none !important;
    }
    .bpWebchat {
      position: absolute !important;
      top: 0 !important; left: 0 !important;
      right: 0 !important; bottom: 0 !important;
      width: 100% !important; height: 100% !important;
      max-height: 100% !important;
    }
  </style>
</head>
<body>
  <div id="webchat-container">
    <script>
      window.botpress = {
        ...(window.botpress || {}),
        configuration: { hideWidget: true }
      };
    </script>
    <script src="https://cdn.botpress.cloud/webchat/v3.6/inject.js"></script>
    <script src="https://files.bpcontent.cloud/2026/07/12/05/20260712052600-YOL9H4YB.js"></script>
    <script>
      window.botpress.on('webchat:ready', function() {
        BotpressBridge.postMessage('ready');
        window.botpress.open();
      });
      window.botpress.on('webchat:closed', function() {
        BotpressBridge.postMessage('closed');
      });
    </script>
    <script>
      (function() {
        var observer = new MutationObserver(function(mutations) {
          mutations.forEach(function(mutation) {
            mutation.addedNodes.forEach(function(node) {
              if (node.nodeType === 1) {
                var el = node;
                if (el.matches && (
                  el.matches('.bpFab, .bp-widget-launcher, .bpWidget, .bp-launcher') ||
                  el.matches('[class*="floating"]') ||
                  el.matches('[class*="launcher"]') ||
                  el.matches('[id*="botpress"]') ||
                  el.matches('[data-testid*="launcher"]')
                )) {
                  el.remove();
                }
                if (el.querySelectorAll) {
                  var found = el.querySelectorAll('.bpFab, .bp-widget-launcher, .bpWidget, .bp-launcher, [class*="floating"], [class*="launcher"], [id*="botpress"], [data-testid*="launcher"]');
                  found.forEach(function(f) { f.remove(); });
                }
              }
            });
          });
        });
        observer.observe(document.body || document.documentElement, {
          childList: true,
          subtree: true
        });
      })();
    </script>
  </div>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lienzo,
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.sol),
                    SizedBox(height: 16),
                    Text(
                      'Conectando con EcuGuía...',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.musgo,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
