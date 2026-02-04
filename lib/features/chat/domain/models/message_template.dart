class MessageTemplate {
  final String id;
  final String title;
  final String content;

  MessageTemplate({
    required this.id,
    required this.title,
    required this.content,
  });

  Map<String, dynamic> toJson() {
    return {'id': id, 'title': title, 'content': content};
  }

  factory MessageTemplate.fromJson(Map<String, dynamic> json) {
    return MessageTemplate(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
    );
  }

  MessageTemplate copyWith({String? id, String? title, String? content}) {
    return MessageTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
    );
  }
}
