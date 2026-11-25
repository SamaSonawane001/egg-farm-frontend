import 'package:flutter/material.dart';

Future<void> showLegalDocuments(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => const _LegalDocumentsSheet(),
  );
}

class _LegalDocumentsSheet extends StatelessWidget {
  const _LegalDocumentsSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .9,
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Terms & Conditions • Privacy Policy',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const TabBar(
              tabs: [
                Tab(text: 'English'),
                Tab(text: 'मराठी'),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  _LegalContent(marathi: false),
                  _LegalContent(marathi: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalContent extends StatelessWidget {
  final bool marathi;

  const _LegalContent({required this.marathi});

  @override
  Widget build(BuildContext context) {
    final sections = marathi ? _marathiSections : _englishSections;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        for (final section in sections)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(section.$1,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(section.$2),
                ],
              ),
            ),
          ),
        Text(
          marathi
              ? 'दस्तऐवज आवृत्ती: v1.0-2027'
              : 'Document version: v1.0-2027',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

const _englishSections = <(String, String)>[
  (
    'Consent & data notice',
    'By creating an account, you consent to using your name, farm details, and mobile number for farm accounting, billing, and OTP verification. The app also processes the farm operational and invoice records you enter, including customer/contact and payment details, and business profile assets you upload, to provide these features.',
  ),
  (
    'Terms & Conditions',
    '1. Eligibility (18+): You confirm that you are at least 18 years old and authorized to manage the poultry farm business.\n\n'
        '2. App purpose & your responsibility: Egg Farm Manager is a digital record-keeping and billing tool. You are responsible for verifying stock, mortality, feed, medicine dosages, GST/tax figures, and keeping backups of critical business records.\n\n'
        '3. Account security: Keep your password and OTP confidential. Do not misuse customer phone numbers or send spam invoices.\n\n'
        '4. Subscription & availability: The software is provided as-is, with reasonable efforts toward availability and support. Temporary interruptions or data connectivity issues may occur.',
  ),
  (
    'Privacy Policy — data collected and purpose',
    'We use owner name, farm/unit details, mobile number, farm operational and invoice records, customer/contact and payment records entered by you, and business profile assets you upload. This information is used to provide multi-farm management, record keeping, PDF invoicing, and OTP authentication. Please do not enter information that is not needed for these purposes.',
  ),
  (
    'Security, sharing & retention',
    'Farm records are scoped to the owner account. Data is protected in transit when you use the service over HTTPS and is not sold to third-party advertisers. Information may be processed by service providers needed to operate the app. Records are retained while your account is active and as required for legitimate business, security, or legal purposes.',
  ),
  (
    'Your rights and requests',
    'You may update your profile in the app and request access, export, correction, withdrawal of consent, or account and associated-record deletion by contacting the support/grievance officer below. Some records may need to be retained where applicable law requires it. Withdrawal may affect features that need the relevant data.',
  ),
  (
    'Grievance & support contact',
    'Support Email: eggfarmsupport@gmail.com\n'
        'Support / WhatsApp: +91 8208810742\n'
        'Grievance Officer: Samadhan Sonawane\n\n'
        'Please include your account mobile number and a description of your request; do not send your password or OTP. We will acknowledge and address grievances within the timelines required by applicable law. If unresolved, you may escalate to the Data Protection Board of India or other authority as provided under applicable Indian data-protection law.',
  ),
];

const _marathiSections = <(String, String)>[
  (
    'संमती व माहितीची सूचना',
    'खाते तयार करून, आपण आपले नाव, फार्मची माहिती आणि मोबाइल नंबर फार्मचा हिशोब, बिलिंग आणि OTP पडताळणीसाठी वापरण्यास संमती देता. ही वैशिष्ट्ये देण्यासाठी ॲप आपण भरलेल्या फार्मच्या कामकाजाच्या व बिलांच्या नोंदी (ग्राहक/संपर्क आणि पेमेंटच्या माहितीसह) तसेच आपण अपलोड केलेली व्यवसाय प्रोफाइल सामग्री देखील प्रक्रिया करते.',
  ),
  (
    'अटी व शर्ती',
    '१. पात्रता (१८ वर्षे किंवा अधिक): आपण किमान १८ वर्षांचे आहात आणि पोल्ट्री फार्म व्यवसाय व्यवस्थापित करण्याचा अधिकार आपल्याकडे आहे, याची आपण पुष्टी करता.\n\n'
        '२. ॲपचा उद्देश व आपली जबाबदारी: Egg Farm Manager हे डिजिटल नोंदवही व बिलिंग साधन आहे. स्टॉक, मृत्यूची नोंद, खाद्य, औषधांचे डोस, GST/कराची आकडेवारी तपासणे आणि महत्त्वाच्या व्यावसायिक नोंदींचा बॅकअप ठेवणे ही आपली जबाबदारी आहे.\n\n'
        '३. खाते सुरक्षा: आपला पासवर्ड आणि OTP गोपनीय ठेवा. ग्राहकांचे फोन नंबर गैरवापरासाठी वापरू नका किंवा स्पॅम बिले पाठवू नका.\n\n'
        '४. सदस्यता व सेवा उपलब्धता: सॉफ्टवेअर जसे आहे तसे दिले जाते. सेवा उपलब्धता व मदतीसाठी वाजवी प्रयत्न केले जातील; तात्पुरते व्यत्यय किंवा इंटरनेट समस्यांमुळे सेवा प्रभावित होऊ शकते.',
  ),
  (
    'गोपनीयता धोरण — गोळा केलेली माहिती व उद्देश',
    'आम्ही मालकाचे नाव, फार्म/युनिटची माहिती, मोबाइल नंबर, फार्मचे कामकाज व बिलांची नोंद, आपण भरलेली ग्राहक/संपर्क व पेमेंटची माहिती आणि आपण अपलोड केलेली व्यवसाय प्रोफाइल सामग्री वापरतो. ही माहिती अनेक फार्मचे व्यवस्थापन, नोंदी ठेवणे, PDF बिल तयार करणे आणि OTP पडताळणीसाठी वापरली जाते. या उद्देशांसाठी आवश्यक नसलेली माहिती भरू नका.',
  ),
  (
    'सुरक्षा, माहितीची देवाणघेवाण व साठवण',
    'फार्मच्या नोंदी मालकाच्या खात्यानुसार स्वतंत्र ठेवल्या जातात. सेवा HTTPS वर वापरल्यास माहिती पाठवताना सुरक्षित केली जाते आणि ती तृतीय-पक्ष जाहिरातदारांना विकली जात नाही. ॲप चालवण्यासाठी आवश्यक सेवा-पुरवठादार माहिती प्रक्रिया करू शकतात. खाते सक्रिय असेपर्यंत आणि व्यावसायिक, सुरक्षा किंवा कायदेशीर कारणांसाठी आवश्यक असेपर्यंत नोंदी ठेवल्या जातात.',
  ),
  (
    'आपले अधिकार व विनंत्या',
    'आपण ॲपमध्ये प्रोफाइल अद्ययावत करू शकता आणि माहिती पाहणे, निर्यात, दुरुस्ती, संमती मागे घेणे किंवा खाते व संबंधित नोंदी हटवण्याची विनंती खालील सहाय्य/तक्रार अधिकाऱ्याशी संपर्क करून करू शकता. लागू कायद्यानुसार काही नोंदी ठेवणे आवश्यक असू शकते. संमती मागे घेतल्यास संबंधित माहितीची गरज असलेली काही वैशिष्ट्ये उपलब्ध राहणार नाहीत.',
  ),
  (
    'तक्रार व सहाय्य संपर्क',
    'सहाय्य ईमेल: eggfarmsupport@gmail.com\n'
        'सहाय्य / WhatsApp: +91 8208810742\n'
        'तक्रार अधिकारी: Samadhan Sonawane (समाधान सोनवणे)\n\n'
        'कृपया आपल्या खात्याचा मोबाइल नंबर आणि विनंतीचे वर्णन द्या; पासवर्ड किंवा OTP पाठवू नका. लागू कायद्यानुसार आवश्यक कालमर्यादेत तक्रारीची दखल घेऊन ती सोडवण्याचा प्रयत्न केला जाईल. तक्रार न सुटल्यास लागू भारतीय डेटा-संरक्षण कायद्यानुसार Data Protection Board of India किंवा संबंधित प्राधिकरणाकडे दाद मागता येईल.',
  ),
];
