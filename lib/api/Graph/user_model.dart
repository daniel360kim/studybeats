/// Represents a user in the system.
///
/// Each user has a variety of properties including business phones, display name, given name,
/// job title, mail, mobile phone, office location, preferred language, surname,
/// user principal name, and an id.
class GraphUser {
  final List<String>? businessPhones;
  final String? displayName;
  final String? givenName;
  final String? jobTitle;
  final String? mail;
  final String? mobilePhone;
  final String? officeLocation;
  final String? preferredLanguage;
  final String? surname;
  final String? userPrincipalName;
  final String? id;

  /// Constructs a [GraphUser] with the provided properties.
  ///
  /// All properties can be null, representing an unknown or not provided value.
  GraphUser({
    this.businessPhones,
    this.displayName,
    this.givenName,
    this.jobTitle,
    this.mail,
    this.mobilePhone,
    this.officeLocation,
    this.preferredLanguage,
    this.surname,
    this.userPrincipalName,
    this.id,
  });

  /// Constructs an empty [GraphUser] where all properties are null.
  const GraphUser.empty()
      : businessPhones = null,
        displayName = null,
        givenName = null,
        jobTitle = null,
        mail = null,
        mobilePhone = null,
        officeLocation = null,
        preferredLanguage = null,
        surname = null,
        userPrincipalName = null,
        id = null;

  /// Constructs a [GraphUser] from a JSON map.
  ///
  /// If a property is not present in the map, the corresponding property will be null.
  factory GraphUser.fromJson(Map<String, dynamic> json) {
    return GraphUser(
      businessPhones: json['businessPhones'] != null
          ? List<String>.from(json['businessPhones'])
          : null,
      displayName: json['displayName'],
      givenName: json['givenName'],
      jobTitle: json['jobTitle'],
      mail: json['mail'],
      mobilePhone: json['mobilePhone'],
      officeLocation: json['officeLocation'],
      preferredLanguage: json['preferredLanguage'],
      surname: json['surname'],
      userPrincipalName: json['userPrincipalName'],
      id: json['id'],
    );
  }

  /// Returns a new [GraphUser] where the properties are the same as this one unless specified in the arguments.
  ///
  /// The arguments specify new values for the corresponding properties in the returned [GraphUser].
  /// If an argument is not provided or is null, the corresponding property in the returned [GraphUser]
  /// will have the same value as that property in this [GraphUser].
  GraphUser copyWith({
    List<String>? businessPhones,
    String? displayName,
    String? givenName,
    String? jobTitle,
    String? mail,
    String? mobilePhone,
    String? officeLocation,
    String? preferredLanguage,
    String? surname,
    String? userPrincipalName,
    String? id,
  }) {
    return GraphUser(
      businessPhones: businessPhones ?? this.businessPhones,
      displayName: displayName ?? this.displayName,
      givenName: givenName ?? this.givenName,
      jobTitle: jobTitle ?? this.jobTitle,
      mail: mail ?? this.mail,
      mobilePhone: mobilePhone ?? this.mobilePhone,
      officeLocation: officeLocation ?? this.officeLocation,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      surname: surname ?? this.surname,
      userPrincipalName: userPrincipalName ?? this.userPrincipalName,
      id: id ?? this.id,
    );
  }
}
