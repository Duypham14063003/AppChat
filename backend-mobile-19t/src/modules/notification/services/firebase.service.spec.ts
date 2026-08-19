import { FirebaseService } from './firebase.service';

var sendMock = jest.fn();

jest.mock('firebase-admin', () => ({
  messaging: () => ({
    send: sendMock,
  }),
}));

describe('FirebaseService', () => {
  let service: FirebaseService;

  beforeEach(() => {
    jest.clearAllMocks();
    service = new FirebaseService({ get: jest.fn() } as any);
    (service as any).initialized = true;
  });

  it('sends APNs badge using the computed unread count', async () => {
    await service.sendPush('token-1', 'Title', 'Body', { type: 'chat' }, 7);

    expect(sendMock).toHaveBeenCalledWith(
      expect.objectContaining({
        token: 'token-1',
        apns: expect.objectContaining({
          payload: {
            aps: { sound: 'default', badge: 7 },
          },
        }),
      }),
    );
  });

  it('clamps negative badge counts to zero', async () => {
    await service.sendPush('token-1', 'Title', 'Body', { type: 'chat' }, -3);

    expect(sendMock).toHaveBeenCalledWith(
      expect.objectContaining({
        apns: expect.objectContaining({
          payload: {
            aps: { sound: 'default', badge: 0 },
          },
        }),
      }),
    );
  });

  it('marks SenderId mismatch as removable for regular push delivery', async () => {
    sendMock.mockRejectedValueOnce(new Error('SenderId mismatch'));

    await expect(
      service.sendPush('token-1', 'Title', 'Body', { type: 'chat' }, 1),
    ).resolves.toEqual({
      success: false,
      shouldRemoveToken: true,
    });
  });

  it('marks SenderId mismatch as removable for call push delivery', async () => {
    sendMock.mockRejectedValueOnce(new Error('SenderId mismatch'));

    await expect(
      service.sendCallPush('token-1', { type: 'call_invite', call_id: '1' }),
    ).resolves.toEqual({
      success: false,
      shouldRemoveToken: true,
    });
  });
});
