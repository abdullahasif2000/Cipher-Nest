import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MaliciousLinkDetectorScreen extends StatefulWidget {
  const MaliciousLinkDetectorScreen({super.key});

  @override
  State<MaliciousLinkDetectorScreen> createState() =>
      _MaliciousLinkDetectorScreenState();
}

class _MaliciousLinkDetectorScreenState
    extends State<MaliciousLinkDetectorScreen> {
  final TextEditingController _linkController = TextEditingController();
  String _result = '';
  String _explanation = '';
  double _riskScore = 0;

  //  Google Safe Browsing
  Future<bool> _checkWithGoogleSafeBrowsing(String url) async {
    final apiKey = 'AIzaSyACflUeaCYVHqJQaFQ7Sn85jEXMWHwFA-Q';
    final apiUrl =
        'https://safebrowsing.googleapis.com/v4/threatMatches:find?key=$apiKey';

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        "client": {
          "clientId": "your-app-id",
          "clientVersion": "1.0.0"
        },
        "threatInfo": {
          "threatTypes": ["MALWARE", "SOCIAL_ENGINEERING"],
          "platformTypes": ["ANY_PLATFORM"],
          "threatEntryTypes": ["URL"],
          "threatEntries": [
            {"url": url}
          ]
        }
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['matches'] != null) {
        _explanation += 'Google Safe Browsing has flagged this link as potentially dangerous.\n';
        _riskScore += 30;
        return true;
      } else {
        _explanation += 'Google Safe Browsing did not flag this link.\n';
      }
    }
    return false;
  }

  //  using VirusTotal
  Future<bool> _checkWithVirusTotal(String url) async {
    final apiKey = 'b5312179940ba629791455634cc8ced6b0902d94b42b9d28dc784019b30bec1f';
    final baseUrl = 'https://www.virustotal.com/api/v3/urls/';
    final encodedUrl = base64Url.encode(utf8.encode(url)).replaceAll('=', '');

    final response = await http.get(
      Uri.parse(baseUrl + encodedUrl),
      headers: {
        'x-apikey': apiKey,
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['data'] != null) {
        final lastAnalysisStats = data['data']['attributes']['last_analysis_stats'];
        final maliciousCount = lastAnalysisStats['malicious'] ?? 0;
        final suspiciousCount = lastAnalysisStats['suspicious'] ?? 0;

        if (maliciousCount > 0 || suspiciousCount > 0) {
          _explanation += 'VirusTotal has flagged this link as suspicious or malicious.\n';
          _riskScore += 50;
          return true;
        } else {
          _explanation += 'VirusTotal did not flag this link.\n';
        }
      }
    }
    return false;
  }

  //  using urlscan.io
  Future<bool> _checkWithUrlscan(String url) async {
    final apiUrl = 'https://urlscan.io/api/v1/scan/';
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'API-Key': 'a22aacc4-2a40-4db2-926b-5ab3298817b2',
      },
      body: json.encode({
        "url": url,
        "visibility": "public",
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['message'] == 'success') {
        final scanResultUrl = data['data']['uri'];
        _explanation += 'URLscan.io has completed a scan on this link. View results: $scanResultUrl\n';
        _riskScore += 20;
        return true;
      } else {
        _explanation += 'URLscan.io did not flag this link.\n';
      }
    }
    return false;
  }

  // Combined function to check all APIs
  Future<void> _checkLink() async {
    final url = _linkController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _result = 'Please enter a valid URL.';
        _explanation = '';
        _riskScore = 0; // Reset risk score
      });
      return;
    }

    setState(() {
      _result = 'Checking the URL...';
      _explanation = '';
      _riskScore = 0; // Reset risk score on each check
    });

    bool isMalicious = false;

    // Check with Google Safe Browsing
    bool googleSafeBrowsingResult = await _checkWithGoogleSafeBrowsing(url);
    if (googleSafeBrowsingResult) {
      isMalicious = true;
    }

    // Check with VirusTotal if not already flagged
    if (!isMalicious) {
      bool virusTotalResult = await _checkWithVirusTotal(url);
      if (virusTotalResult) {
        isMalicious = true;
      }
    }

    // Check with urlscan.io if not already flagged
    if (!isMalicious) {
      bool urlscanResult = await _checkWithUrlscan(url);
      if (urlscanResult) {
        isMalicious = true;
      }
    }

    // Final result based on the risk score
    setState(() {
      _result = isMalicious
          ? 'The link is flagged as malicious!'
          : 'The link appears safe.';
    });
  }

  String getRiskLevel(double score) {
    if (score >= 75) {
      return 'High Risk';
    } else if (score >= 50) {
      return 'Moderate Risk';
    } else if (score >= 25) {
      return 'Low Risk';
    } else {
      return 'Safe';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Malicious Link Detector'),
        backgroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            TextField(
              controller: _linkController,
              decoration: InputDecoration(
                labelText: 'Paste a link',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _checkLink,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text('Check Link'),
            ),
            const SizedBox(height: 20),
            Card(
              color: _result.contains('malicious') ? Colors.red[100] : Colors.green[100],
              elevation: 5,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _result,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _result.contains('malicious') ? Colors.red : Colors.green,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_explanation.isNotEmpty)
                      Text(
                        _explanation,
                        style: const TextStyle(fontSize: 14),
                      ),
                    const SizedBox(height: 20),
                    LinearProgressIndicator(
                      value: _riskScore / 100,
                      color: _riskScore >= 75
                          ? Colors.red
                          : _riskScore >= 50
                          ? Colors.orange
                          : _riskScore >= 25
                          ? Colors.yellow
                          : Colors.green,
                      backgroundColor: Colors.grey[300],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      getRiskLevel(_riskScore),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _riskScore >= 75
                            ? Colors.red
                            : _riskScore >= 50
                            ? Colors.orange
                            : _riskScore >= 25
                            ? Colors.yellow
                            : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
