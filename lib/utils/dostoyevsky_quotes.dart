/// Daily quotes from Dostoyevsky's works
class DostoyevskyQuotes {
  static const List<Map<String, String>> arabicQuotes = [
    {
      'quote':
          'الجريمة والعقاب تتبع بعضهما البعض، ولا يمكن الفصل بينهما. إنهما وجهان لعملة واحدة.',
      'source': 'الجريمة والعقاب',
    },
    {
      'quote':
          'الألم والمعاناة هما دائمًا ثمناً للإدراك العميق. من يريد معرفة الكثير يجب أن يتألم كثيرًا.',
      'source': 'الإخوة كارامازوف',
    },
    {
      'quote':
          'الجمال سينقذ العالم. لكن الجمال الحقيقي هو ذلك الذي ينبع من الداخل، من الروح.',
      'source': 'الأبله',
    },
    {
      'quote':
          'الحرية الحقيقية ليست في فعل ما تريد، بل في السيطرة على نفسك وإرادتك.',
      'source': 'مذكرات من قبو',
    },
    {
      'quote':
          'الحب هو كل شيء. الحب هو القوة الوحيدة التي يمكنها إنقاذ العالم من الشر.',
      'source': 'الشياطين',
    },
    {
      'quote':
          'الإنسان ليس مجرد كائن عاقل، بل هو أيضاً كائن يحتاج إلى المعاناة لفهم الحياة.',
      'source': 'الإخوة كارامازوف',
    },
    {
      'quote':
          'الأمل موجود دائماً، حتى في أحلك اللحظات. الأمل هو آخر ما يموت في قلب الإنسان.',
      'source': 'الجريمة والعقاب',
    },
  ];

  static const List<Map<String, String>> englishQuotes = [
    {
      'quote':
          'Crime and punishment follow each other, and cannot be separated. They are two sides of the same coin.',
      'source': 'Crime and Punishment',
    },
    {
      'quote':
          'Pain and suffering are always the price of deep awareness. Those who want to know much must suffer much.',
      'source': 'The Brothers Karamazov',
    },
    {
      'quote':
          'Beauty will save the world. But true beauty is that which comes from within, from the soul.',
      'source': 'The Idiot',
    },
    {
      'quote':
          'True freedom is not in doing what you want, but in controlling yourself and your will.',
      'source': 'Notes from Underground',
    },
    {
      'quote':
          'Love is everything. Love is the only force that can save the world from evil.',
      'source': 'Demons',
    },
    {
      'quote':
          'Man is not merely a rational being, but also a being who needs suffering to understand life.',
      'source': 'The Brothers Karamazov',
    },
    {
      'quote':
          'Hope always exists, even in the darkest moments. Hope is the last thing to die in a man\'s heart.',
      'source': 'Crime and Punishment',
    },
  ];

  static const List<Map<String, String>> russianQuotes = [
    {
      'quote':
          'Преступление и наказание следуют друг за другом и не могут быть разделены. Это две стороны одной медали.',
      'source': 'Преступление и наказание',
    },
    {
      'quote':
          'Боль и страдание всегда являются ценой глубокого осознания. Тот, кто хочет много знать, должен много страдать.',
      'source': 'Братья Карамазовы',
    },
    {
      'quote':
          'Красота спасёт мир. Ho истинная красота - это та, что исходит изнутри, из души.',
      'source': 'Идиот',
    },
    {
      'quote':
          'Истинная свобода не в том, чтобы делать то, что хочешь, a в том, чтобы контролировать себя и свою волю.',
      'source': 'Записки из подполья',
    },
    {
      'quote':
          'Любовь — это всё. Любовь — единственная сила, которая может спасти мир от зла.',
      'source': 'Бесы',
    },
    {
      'quote':
          'Человек не просто разумное существо, но и существо, которому нужно страдание, чтобы понять жизнь.',
      'source': 'Братья Карамазовы',
    },
    {
      'quote':
          'Надежда всегда существует, даже в самые тёмные моменты. Надежда — последнее, что умирает в сердце человека.',
      'source': 'Преступление и наказание',
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
