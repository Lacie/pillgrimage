import 'dart:convert';
import 'package:http/http.dart' as http;

class SendGridService {
  static const String _apiKey = '??? APPI KEY PLEASE';
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
      print("Success: Email is being processed.");
    } else {
      print("Error ${response.statusCode}: ${response.body}");
    }
  }
}
