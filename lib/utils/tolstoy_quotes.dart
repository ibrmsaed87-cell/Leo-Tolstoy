/// Daily quotes from Tolstoy's works
class TolstoyQuotes {
  static const List<Map<String, String>> arabicQuotes = [
    {
      'quote':
          'كل الناس يعيشون، لكن ليس كل الناس يعرفون لماذا يعيشون.',
      'source': 'الحرب والسلام',
    },
    {
      'quote':
          'السعادة الحقيقية لا تأتي من الخارج، بل من الداخل، من السلام الداخلي.',
      'source': 'آنا كارينينا',
    },
    {
      'quote':
          'الحب هو الحياة. كل شيء، كل شيء أفهمه، أفهمه فقط من خلال الحب.',
      'source': 'الحرب والسلام',
    },
    {
      'quote':
          'الطريقة الوحيدة للعيش هي أن تعيش من أجل الآخرين.',
      'source': 'آنا كارينينا',
    },
    {
      'quote':
          'إذا كنت تريد أن تكون سعيداً، كن كذلك.',
      'source': 'الحرب والسلام',
    },
    {
      'quote':
          'الخير والشر موجودان في كل إنسان، لكن الإنسان الحكيم يعرف كيف يختار.',
      'source': 'آنا كارينينا',
    },
    {
      'quote':
          'الحياة الحقيقية هي الحياة التي نعيشها من أجل الآخرين.',
      'source': 'الحرب والسلام',
    },
  ];

  static const List<Map<String, String>> englishQuotes = [
    {
      'quote':
          'Everyone thinks of changing the world, but no one thinks of changing himself.',
      'source': 'War and Peace',
    },
    {
      'quote':
          'All happy families are alike; each unhappy family is unhappy in its own way.',
      'source': 'Anna Karenina',
    },
    {
      'quote':
          'The two most powerful warriors are patience and time.',
      'source': 'War and Peace',
    },
    {
      'quote':
          'If you want to be happy, be.',
      'source': 'War and Peace',
    },
    {
      'quote':
          'The sole meaning of life is to serve humanity.',
      'source': 'Anna Karenina',
    },
    {
      'quote':
          'Truth, like gold, is to be obtained not by its growth, but by washing away from it all that is not gold.',
      'source': 'War and Peace',
    },
    {
      'quote':
          'We can know only that we know nothing. And that is the highest degree of human wisdom.',
      'source': 'War and Peace',
    },
  ];

  static const List<Map<String, String>> russianQuotes = [
    {
      'quote':
          'Все счастливые семьи похожи друг на друга, каждая несчастливая семья несчастлива по-своему.',
      'source': 'Анна Каренина',
    },
    {
      'quote':
          'Все думают об изменении мира, но никто не думает об изменении себя.',
      'source': 'Война и мир',
    },
    {
      'quote':
          'Два самых могущественных воина - это терпение и время.',
      'source': 'Война и мир',
    },
    {
      'quote':
          'Если хочешь быть счастливым, будь им.',
      'source': 'Война и мир',
    },
    {
      'quote':
          'Единственный смысл жизни - служить человечеству.',
      'source': 'Анна Каренина',
    },
    {
      'quote':
          'Истина, как золото, добывается не ростом, а смыванием всего, что не золото.',
      'source': 'Война и мир',
    },
    {
      'quote':
          'Мы можем знать только то, что мы ничего не знаем. И это высшая степень человеческой мудрости.',
      'source': 'Война и мир',
    },
  ];

  /// Get quote of the day based on current date
  static Map<String, String> getQuoteOfTheDay(bool isArabic) {
    final quotes = isArabic ? arabicQuotes : englishQuotes;
    final dayOfYear = DateTime.now()
        .difference(DateTime(DateTime.now().year, 1, 1))
        .inDays;
    return quotes[dayOfYear % quotes.length];
  }

  /// Get quote of the day based on language code
  static Map<String, String> getQuoteOfTheDayByLanguage(String languageCode) {
    final List<Map<String, String>> quotes;
    if (languageCode == 'ar') {
      quotes = arabicQuotes;
    } else if (languageCode == 'ru') {
      quotes = russianQuotes;
    } else {
      quotes = englishQuotes;
    }
    final dayOfYear = DateTime.now()
        .difference(DateTime(DateTime.now().year, 1, 1))
        .inDays;
    return quotes[dayOfYear % quotes.length];
  }
}


