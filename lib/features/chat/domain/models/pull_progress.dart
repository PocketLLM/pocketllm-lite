class PullProgress {
  final String status;
  final int completed;
  final int total;
  final double percentage;

  const PullProgress({
    required this.status,
    this.completed = 0,
    this.total = 0,
    this.percentage = 0.0,
  });

  factory PullProgress.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as String? ?? '';
    final completed = json['completed'] as int? ?? 0;
    final total = json['total'] as int? ?? 0;

    double percentage = 0.0;
    if (total > 0) {
      percentage = (completed / total).clamp(0.0, 1.0);
    }

    return PullProgress(
      status: status,
      completed: completed,
      total: total,
      percentage: percentage,
    );
  }

  @override
  String toString() {
    return 'PullProgress(status: $status, percentage: ${(percentage * 100).toStringAsFixed(1)}%)';
  }
}
