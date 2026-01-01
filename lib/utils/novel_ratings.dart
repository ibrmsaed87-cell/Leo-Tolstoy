/// Predefined ratings for Dostoyevsky novels
class NovelRatings {
  static const Map<String, double> ratings = {
    // Arabic
    'الجريمة والعقاب': 4.8,
    'الإخوة كارامازوف': 4.9,
    'الأبله': 4.7,
    'الشياطين': 4.6,
    'المقامر': 4.4,
    'مذكرات من قبو': 4.5,
    'حلم العم': 4.3,
    'الزوج الأبدي': 4.2,
    'الليالي البيضاء وقصص اخرى': 4.5,
    // English
    'Crime and Punishment': 4.8,
    'The Brothers Karamazov': 4.9,
    'The Idiot': 4.7,
    'Demons': 4.6,
    'The Gambler': 4.4,
    'Notes from the Underground': 4.5,
    'Poor Folk': 4.3,
    'The Grand Inquisitor': 4.6,
    'The house of the dead': 4.4,
    'Uncles Dream and The Permanent Husband': 4.3,
    'Short Stories': 4.5,
    'White Nights and Other Stories': 4.5,
  };

  static double getRating(String title) {
    return ratings[title] ?? 4.5;
  }
}



