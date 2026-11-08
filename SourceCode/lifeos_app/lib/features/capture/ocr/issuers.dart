/// Known Pakistani utility and telecom issuers (PBI-004 grooming), with
/// spelling variants seen on bills. Canonical name first.
const knownIssuers = <String, List<String>>{
  'K-Electric': ['k-electric', 'k electric', 'kelectric', 'karachi electric'],
  'LESCO': ['lesco', 'lahore electric'],
  'IESCO': ['iesco', 'islamabad electric'],
  'MEPCO': ['mepco', 'multan electric'],
  'PESCO': ['pesco', 'peshawar electric'],
  'SSGC': ['ssgc', 'sui southern'],
  'SNGPL': ['sngpl', 'sui northern'],
  'PTCL': ['ptcl', 'pakistan telecommunication'],
  'StormFiber': ['stormfiber', 'storm fiber'],
  'Nayatel': ['nayatel'],
  'Jazz': ['jazz', 'mobilink'],
  'Zong': ['zong'],
  'Telenor': ['telenor'],
  'Ufone': ['ufone'],
  'WASA': ['wasa', 'water and sanitation', 'kw&sc', 'karachi water'],
};

/// The canonical issuer named in [text], if any.
String? findIssuer(String text) {
  final lower = text.toLowerCase();
  for (final entry in knownIssuers.entries) {
    if (entry.value.any(lower.contains)) return entry.key;
  }
  return null;
}
