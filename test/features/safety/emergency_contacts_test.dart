import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seddo/core/utils/api_endpoints.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/safety/data/models/safety_contact_model.dart';
import 'package:seddo/features/safety/data/repositories/safety_repository.dart';
import 'package:seddo/features/safety/data/services/safety_service.dart';
import 'package:seddo/features/safety/domain/bloc/safety_bloc.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SafetyContactModel Tests', () {
    test('toApiJson serializes only name and phone for ContactDto', () {
      const contact = SafetyContactModel(
        id: 'c1',
        name: 'Fatou Diop',
        relationship: 'safety.relation_friend',
        phone: '77 555 12 12',
        avatarThemeIndex: 1,
      );

      final apiJson = contact.toApiJson();
      expect(apiJson, {
        'name': 'Fatou Diop',
        'phone': '77 555 12 12',
      });
      expect(apiJson.containsKey('id'), isFalse);
      expect(apiJson.containsKey('relationship'), isFalse);
    });

    test('fromJson parses API ContactDto without id and assigns index', () {
      final json = {
        'name': 'Moussa Sall',
        'phone': '78 123 45 67',
      };

      final contact = SafetyContactModel.fromJson(json, index: 1);
      expect(contact.name, 'Moussa Sall');
      expect(contact.phone, '78 123 45 67');
      expect(contact.id, '78 123 45 67');
      expect(contact.avatarThemeIndex, 1);
    });

    test('initials computation works for 1, 2 or more words', () {
      const c1 = SafetyContactModel(
        id: '1',
        name: 'Awa Fall',
        relationship: '',
        phone: '770000000',
      );
      expect(c1.initials, 'AF');

      const c2 = SafetyContactModel(
        id: '2',
        name: 'Seddo',
        relationship: '',
        phone: '770000001',
      );
      expect(c2.initials, 'SE');
    });
  });

  group('SafetyService Emergency Contacts API Tests', () {
    late Dio dio;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      dio = Dio(BaseOptions(baseUrl: ApiEndpoints.baseUrl));
    });

    test('fetchEmergencyContacts handles remote GET and saves to cache', () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('/v1/users/me/emergency-contacts')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {'name': 'Ami Ndiaye', 'phone': '77 111 22 33'},
                    {'name': 'Ousmane Ba', 'phone': '78 222 33 44'},
                  ],
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final service = SafetyService(prefs, dio);
      final contacts = await service.fetchEmergencyContacts();

      expect(contacts.length, 2);
      expect(contacts[0].name, 'Ami Ndiaye');
      expect(contacts[0].phone, '77 111 22 33');
      expect(contacts[1].name, 'Ousmane Ba');
      expect(contacts[1].phone, '78 222 33 44');
    });

    test('setEmergencyContacts caps list at AppConstants.maxEmergencyContacts (3)', () async {
      Map<String, dynamic>? capturedBody;

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('/v1/users/me/emergency-contacts') &&
                options.method == 'PUT') {
              capturedBody = options.data as Map<String, dynamic>?;
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: options.data,
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final service = SafetyService(prefs, dio);
      final list = [
        const SafetyContactModel(id: '1', name: 'C1', relationship: '', phone: '771'),
        const SafetyContactModel(id: '2', name: 'C2', relationship: '', phone: '772'),
        const SafetyContactModel(id: '3', name: 'C3', relationship: '', phone: '773'),
        const SafetyContactModel(id: '4', name: 'C4', relationship: '', phone: '774'),
      ];

      final saved = await service.setEmergencyContacts(list);

      expect(saved.length, AppConstants.maxEmergencyContacts);
      expect(capturedBody, isNotNull);
      final contactsSent = capturedBody!['contacts'] as List<dynamic>;
      expect(contactsSent.length, 3);
      expect(contactsSent[0], {'name': 'C1', 'phone': '771'});
    });
  });

  group('SafetyBloc Emergency Contacts Tests', () {
    late SafetyRepository mockRepo;
    late List<SafetyContactModel> repoContacts;

    setUp(() {
      repoContacts = [
        const SafetyContactModel(id: '1', name: 'Papa Diop', relationship: '', phone: '771112233'),
      ];
      mockRepo = SafetyRepository(
        safetyService: _MockSafetyService(
          initialContacts: repoContacts,
        ),
      );
    });

    test('SafetyLoadRequested loads contacts from repository', () async {
      final bloc = SafetyBloc(repository: mockRepo);

      expect(bloc.state.status, SafetyStatus.initial);
      bloc.add(const SafetyLoadRequested());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<SafetyState>().having((s) => s.status, 'status', SafetyStatus.loading),
          isA<SafetyState>()
              .having((s) => s.status, 'status', SafetyStatus.success)
              .having((s) => s.contacts.length, 'contacts.length', 1)
              .having((s) => s.contacts[0].name, 'contact name', 'Papa Diop'),
        ]),
      );
    });

    test('SafetyContactAdded adds contact and emits userFeedbackMessage', () async {
      final bloc = SafetyBloc(repository: mockRepo);
      bloc.add(const SafetyLoadRequested());
      await bloc.stream.firstWhere((s) => s.status == SafetyStatus.success);

      const newContact = SafetyContactModel(
        id: '2',
        name: 'Khadija Sow',
        relationship: 'safety.relation_friend',
        phone: '782223344',
      );

      bloc.add(const SafetyContactAdded(newContact));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<SafetyState>().having((s) => s.isUpdatingContacts, 'isUpdating', isTrue),
          isA<SafetyState>()
              .having((s) => s.isUpdatingContacts, 'isUpdating', isFalse)
              .having((s) => s.contacts.length, 'contacts.length', 2)
              .having((s) => s.userFeedbackMessage, 'feedback', 'Khadija Sow'),
        ]),
      );
    });

    test('SafetyContactRemoved removes contact from state', () async {
      final bloc = SafetyBloc(repository: mockRepo);
      bloc.add(const SafetyLoadRequested());
      await bloc.stream.firstWhere((s) => s.status == SafetyStatus.success);

      bloc.add(const SafetyContactRemoved('1'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<SafetyState>().having((s) => s.isUpdatingContacts, 'isUpdating', isTrue),
          isA<SafetyState>()
              .having((s) => s.isUpdatingContacts, 'isUpdating', isFalse)
              .having((s) => s.contacts.length, 'contacts.length', 0),
        ]),
      );
    });
  });
}

class _MockSafetyService extends SafetyService {
  List<SafetyContactModel> _contacts;

  _MockSafetyService({List<SafetyContactModel>? initialContacts})
      : _contacts = initialContacts != null ? List.from(initialContacts) : [];

  @override
  Future<List<SafetyContactModel>> fetchEmergencyContacts() async {
    return List.from(_contacts);
  }

  @override
  Future<List<SafetyContactModel>> setEmergencyContacts(
    List<SafetyContactModel> contacts,
  ) async {
    _contacts = contacts.take(AppConstants.maxEmergencyContacts).toList();
    return List.from(_contacts);
  }

  @override
  Future<List<SafetyContactModel>> addEmergencyContact(
    SafetyContactModel contact,
    List<SafetyContactModel> currentList,
  ) async {
    _contacts = [...currentList, contact].take(AppConstants.maxEmergencyContacts).toList();
    return List.from(_contacts);
  }

  @override
  Future<List<SafetyContactModel>> deleteEmergencyContact(
    String idOrPhone,
    List<SafetyContactModel> currentList,
  ) async {
    _contacts = currentList.where((c) => c.id != idOrPhone && c.phone != idOrPhone).toList();
    return List.from(_contacts);
  }
}
