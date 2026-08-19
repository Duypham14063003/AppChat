import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nineteen_tech_app/features/hr/data/hr_models.dart';
import 'package:nineteen_tech_app/features/hr/data/hr_repository.dart';

void main() {
  group('HrRepository employee management', () {
    test('parses directory, detail and contract payloads', () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter({
          '/hr/employees': {
            'items': [
              {
                'id': 'emp-1',
                'name': 'Nguyen Van A',
                'email': 'a@19t.vn',
                'department': 'Engineering',
                'job_title': 'Flutter Dev',
                'employment_status': 'active',
                'is_active': true,
                'identity_number': 'hidden',
              },
            ],
            'total': 1,
            'page': 1,
            'limit': 20,
          },
          '/hr/employees/emp-1': {
            'id': 'emp-1',
            'name': 'Nguyen Van A',
            'email': 'a@19t.vn',
            'department': 'Engineering',
            'job_title': 'Flutter Dev',
            'employment_status': 'active',
            'is_active': true,
            'profile': {
              'user_id': 'emp-1',
              'current_address': 'Ho Chi Minh',
              'personal_phone': '0900000000',
              'bank_code': 'VCB',
              'bank_account_name': 'NGUYEN VAN A',
              'bank_qr_image_url': '/uploads/hr/payment-qr/a.png',
              'bank_qr_source': 'uploaded',
            },
            'contracts': [
              {
                'id': 'c-1',
                'user_id': 'emp-1',
                'type': 'official',
                'start_date': '2026-01-01',
                'status': 'active',
                'created_by': 'admin-1',
                'days_until_expiry': 10,
              },
            ],
          },
          '/hr/employees/emp-1/contracts': [
            {
              'id': 'c-1',
              'user_id': 'emp-1',
              'type': 'official',
              'start_date': '2026-01-01',
              'status': 'active',
              'created_by': 'admin-1',
            },
          ],
          '/rewards/top-period': {
            'tech': [
              {
                'user_id': 'tech-1',
                'name': 'Tech One',
                'points_earned': 150,
                'period': '2026-07',
              },
              {
                'user_id': 'tech-2',
                'name': 'Tech Two',
                'points_earned': 120,
                'period': '2026-07',
              },
            ],
            'other': [
              {
                'user_id': 'other-1',
                'name': 'Other One',
                'points_earned': 200,
                'period': '2026-07',
              },
            ],
          },
        });

      final repo = HrRepository(dio);
      final directory = await repo.getEmployees();
      final detail = await repo.getEmployeeDetail('emp-1');
      final contracts = await repo.getEmployeeContracts('emp-1');
      final topPeriod = await repo.getRewardsTopPeriod(period: '2026-07');

      expect(directory.items, hasLength(1));
      expect(directory.items.first.name, 'Nguyen Van A');
      expect(directory.items.first.department, 'Engineering');
      expect(
        directory.items.first,
        isNot(const TypeMatcher<EmployeeProfile>()),
      );
      expect(detail.profile?.currentAddress, 'Ho Chi Minh');
      expect(detail.profile?.bankCode, 'VCB');
      expect(detail.profile?.bankQrSource, 'uploaded');
      expect(detail.contracts.first.daysUntilExpiry, 10);
      expect(contracts.single.type, 'official');
      expect(topPeriod.tech, hasLength(2));
      expect(topPeriod.tech.first.pointsEarned, 150);
      expect(topPeriod.other.single.userId, 'other-1');
    });

    test(
      'collects every employee directory page and deduplicates IDs',
      () async {
        final requests = <RequestOptions>[];
        final dio = Dio()
          ..httpClientAdapter = _CallbackAdapter((options) {
            requests.add(options);
            final page = options.queryParameters['page'] as int;
            if (page == 1) {
              return {
                'items': [
                  {
                    'id': 'emp-1',
                    'name': 'Employee 1',
                    'email': 'e1@19t.vn',
                    'is_active': true,
                  },
                  {
                    'id': 'emp-2',
                    'name': 'Employee 2',
                    'email': 'e2@19t.vn',
                    'is_active': false,
                  },
                ],
                'total': 3,
                'page': 1,
                'limit': 2,
              };
            }
            return {
              'items': [
                {
                  'id': 'emp-2',
                  'name': 'Employee 2 updated',
                  'email': 'e2@19t.vn',
                  'is_active': false,
                },
                {
                  'id': 'emp-3',
                  'name': 'Employee 3',
                  'email': 'e3@19t.vn',
                  'is_active': true,
                },
              ],
              'total': 3,
              'page': 2,
              'limit': 2,
            };
          });

        final employees = await HrRepository(dio).getAllEmployees(pageSize: 2);

        expect(employees.map((employee) => employee.id), [
          'emp-1',
          'emp-2',
          'emp-3',
        ]);
        expect(employees[1].name, 'Employee 2 updated');
        expect(requests.map((request) => request.queryParameters['page']), [
          1,
          2,
        ]);
      },
    );

    test(
      'serializes employee leave filters and parses payroll summary',
      () async {
        final requests = <RequestOptions>[];
        final dio = Dio()
          ..httpClientAdapter = _CallbackAdapter((options) {
            requests.add(options);
            if (options.path == '/hr/leaves') {
              return {'leaves': [], 'otHours': 0};
            }
            return {
              'user_id': 'emp-1',
              'month': '2026-08',
              'cycle_from': '2026-07-25',
              'cycle_to_exclusive': '2026-08-25',
              'attendance_status': 'available',
              'actual_working_days': 12,
              'attendance_sessions': [
                {
                  'id': 101,
                  'date': '2026-08-08',
                  'check_in': '2026-08-08T01:00:00.000Z',
                  'check_out': '2026-08-08T10:00:00.000Z',
                  'worked_hours': 9,
                  'counted': true,
                  'day_value': 0.5,
                  'exclusion_reason': null,
                },
              ],
              'leave_orders': [
                {
                  'id': 'leave-1',
                  'user_id': 'emp-1',
                  'type': 'annual',
                  'start_date': '2026-08-08',
                  'end_date': '2026-08-08',
                  'is_half_day': true,
                  'half_day_part': 'morning',
                  'requested_days': 0.5,
                  'status': 'approved',
                },
              ],
            };
          });
        final repository = HrRepository(dio);

        await repository.getLeaves(
          status: 'approved',
          userId: 'emp-1',
          year: 2026,
          month: 8,
        );
        final summary = await repository.getEmployeePayrollSummary(
          month: '2026-08',
          userId: 'emp-1',
        );

        expect(requests.first.queryParameters, {
          'status': 'approved',
          'user_id': 'emp-1',
          'year': 2026,
          'month': 8,
        });
        expect(requests.last.queryParameters, {
          'month': '2026-08',
          'user_id': 'emp-1',
        });
        expect(summary.attendanceStatus, AttendanceDataStatus.available);
        expect(summary.actualWorkingDays, 12);
        expect(summary.attendanceSessions.single.id, 101);
        expect(summary.attendanceSessions.single.counted, isTrue);
        expect(summary.attendanceSessions.single.date, '2026-08-08');
        expect(summary.attendanceSessions.single.dayValue, 0.5);
        expect(summary.leaveOrders.single.id, 'leave-1');
        expect(summary.leaveOrders.single.requestedDays, 0.5);
      },
    );

    test('parses unmapped payroll summary without coercing it to zero', () {
      final summary = EmployeePayrollSummary.fromJson(const {
        'user_id': 'emp-1',
        'month': '2026-08',
        'cycle_from': '2026-07-25',
        'cycle_to_exclusive': '2026-08-25',
        'attendance_status': 'unmapped',
        'actual_working_days': null,
      });

      expect(summary.attendanceStatus, AttendanceDataStatus.unmapped);
      expect(summary.actualWorkingDays, isNull);
    });

    test('serializes normalized employee payment fields', () {
      const request = EmployeeProfileUpdateRequest(
        bankCode: 'MB',
        bankName: 'MBBank',
        bankAccountNumber: '123456789',
        bankAccountName: 'NGUYEN VAN A',
        bankQrSource: 'generated',
      );

      expect(request.toJson(), {
        'bank_code': 'MB',
        'bank_name': 'MBBank',
        'bank_account_number': '123456789',
        'bank_account_name': 'NGUYEN VAN A',
        'bank_qr_source': 'generated',
      });
    });

    test('uses self and HR payment QR endpoints', () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..httpClientAdapter = _CallbackAdapter((options) {
          requests.add(options);
          return {
            'user_id': options.path.contains('/emp-1/') ? 'emp-1' : 'self-1',
            'bank_qr_image_url': options.method == 'DELETE'
                ? null
                : '/uploads/hr/payment-qr/qr.png',
            'bank_qr_source': options.method == 'DELETE'
                ? 'generated'
                : 'uploaded',
          };
        });
      final repository = HrRepository(dio);
      final file = XFile.fromData(
        Uint8List.fromList([1, 2, 3]),
        name: 'qr.png',
        mimeType: 'image/png',
      );

      await repository.uploadEmployeePaymentQr(file: file);
      await repository.uploadEmployeePaymentQr(userId: 'emp-1', file: file);
      await repository.deleteEmployeePaymentQr();
      await repository.deleteEmployeePaymentQr(userId: 'emp-1');

      expect(requests.map((request) => request.path), [
        '/hr/employees/me/payment-qr',
        '/hr/employees/emp-1/payment-qr',
        '/hr/employees/me/payment-qr',
        '/hr/employees/emp-1/payment-qr',
      ]);
      expect(requests.map((request) => request.method), [
        'POST',
        'POST',
        'DELETE',
        'DELETE',
      ]);
      final upload = requests.first.data as FormData;
      expect(upload.files.single.value.contentType.toString(), 'image/png');
    });

    test('rejects invalid and oversized payment QR images locally', () async {
      final repository = HrRepository(Dio());

      await expectLater(
        repository.uploadEmployeePaymentQr(
          file: XFile.fromData(Uint8List.fromList([1]), name: 'qr.txt'),
        ),
        throwsArgumentError,
      );
      await expectLater(
        repository.uploadEmployeePaymentQr(
          file: XFile.fromData(
            Uint8List(HrRepository.paymentQrMaxBytes + 1),
            mimeType: 'image/png',
          ),
        ),
        throwsArgumentError,
      );
    });
  });
}

class _CallbackAdapter implements HttpClientAdapter {
  _CallbackAdapter(this.callback);

  final Object? Function(RequestOptions options) callback;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(callback(options)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._responses);

  final Map<String, Object?> _responses;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = _responses[options.path];
    if (body == null) {
      return ResponseBody.fromString(
        jsonEncode({'message': 'not found'}),
        404,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
