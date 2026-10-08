/// Meaningful milestones, deliberately few and tied to real learning (not points or currency).
class MilestoneInputs {
  const MilestoneInputs({
    required this.totalReviews,
    required this.bestStreak,
    required this.matureCards,
    required this.subjectsStarted,
    required this.topicsRevisited,
  });
  final int totalReviews, bestStreak, matureCards, subjectsStarted, topicsRevisited;
}

class Milestone {
  const Milestone(this.id, this.title, this.description, this.progress, this.goal);
  final String id, title, description;
  final int progress, goal;
  bool get earned => progress >= goal;
  double get fraction => goal == 0 ? 1 : (progress / goal).clamp(0.0, 1.0);
}

List<Milestone> milestonesFor(MilestoneInputs m) => [
      Milestone('first', 'First steps', 'Answer your first card.', m.totalReviews, 1),
      Milestone('rhythm', 'Finding a rhythm', 'Answer 100 cards.', m.totalReviews, 100),
      Milestone('week', 'A week of showing up', 'Study 7 days in a row.', m.bestStreak, 7),
      Milestone('root', 'Memory takes root', 'Get your first card to a stable, long-term memory.', m.matureCards, 1),
      Milestone('wide', 'Wide curiosity', 'Start 5 different subjects.', m.subjectsStarted, 5),
      Milestone('round2', 'Round two', 'Return to a finished topic and go deeper.', m.topicsRevisited, 1),
      Milestone('month', 'A month strong', 'Study 30 days in a row.', m.bestStreak, 30),
      Milestone('hundred', 'A hundred memories', '100 cards in long-term memory.', m.matureCards, 100),
      Milestone('thousand', 'A thousand answers', 'Answer 1,000 cards.', m.totalReviews, 1000),
    ];
