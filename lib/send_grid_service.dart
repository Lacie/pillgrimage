import 'dart:convert';
import 'package:http/http.dart' as http;

class SendGridService {
  static const String _apiKey = 'API KEY ENTER HERE ';
  static const String _url = 'https://api.sendgrid.com/v3/mail/send';

  Future<void> sendEmail({
    required String toEmail,
    required String subject,
    required String textContent,
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
          "email": "noreply@pillgrimage.tech", // TODO: Replace with your verified sender email in SendGrid
          "name": "Pillgrimage"
        },
        "content": [
          {
            "type": "text/plain",
            "value": textContent
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
