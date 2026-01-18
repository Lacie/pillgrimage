import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pillgrimage/api_keys.dart';

class SendGridService {
  static const String _apiKey = sendGridApiKey;
  static const String _url = 'https://api.sendgrid.com/v3/mail/send';

  Future<void> sendEmail({
    required String toEmail,
    required String subject,
    String? textContent,
    String? htmlContent,
  }) async {
    final response = await http.post(
      Uri.parse(_url),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "personalizations": [
          {
            "to": [{"email": toEmail}],
            "subject": subject
          }
        ],
        "from": {
          "email": "noreply@pillgrimage.tech",
          "name": "Pillgrimage"
        },
        "content": [
          {
            "type": htmlContent != null ? "text/html" : "text/plain",
            "value": htmlContent ?? textContent ?? ''
          }
        ]
      }),
    );

    if (response.statusCode == 202) {
      if (kDebugMode) {
        print("Success: Email is being processed.");
      }
    } else {
      if (kDebugMode) {
        print("Error ${response.statusCode}: ${response.body}");
      }
    }
  }
}
