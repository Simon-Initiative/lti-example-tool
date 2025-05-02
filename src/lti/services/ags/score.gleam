import gleam/json.{type Json}

pub type Score {
  Score(
    score_given: Float,
    score_maximum: Float,
    timestamp: String,
    user_id: String,
    comment: String,
    activity_progress: String,
    grading_progress: String,
  )
}

pub fn to_json(score: Score) -> Json {
  let Score(
    score_given,
    score_maximum,
    timestamp,
    user_id,
    comment,
    activity_progress,
    grading_progress,
  ) = score

  json.object([
    #("scoreGiven", json.float(score_given)),
    #("scoreMaximum", json.float(score_maximum)),
    #("timestamp", json.string(timestamp)),
    #("userId", json.string(user_id)),
    #("comment", json.string(comment)),
    #("activityProgress", json.string(activity_progress)),
    #("gradingProgress", json.string(grading_progress)),
  ])
}
