import { BadRequestException } from '@nestjs/common';
import { PocService } from './poc.service';

describe('PocService domain rules', () => {
  const service = Object.create(PocService.prototype) as PocService;

  it('allows the intended lifecycle and rejects invalid transitions', () => {
    const assertTransition = (service as any).assertTransition.bind(service);
    expect(() => assertTransition('assigned', 'in_progress')).not.toThrow();
    expect(() => assertTransition('in_progress', 'ready')).not.toThrow();
    expect(() =>
      assertTransition('ready', 'demonstrated', 'completed'),
    ).not.toThrow();
    expect(() => assertTransition('assigned', 'ready')).toThrow(
      BadRequestException,
    );
    expect(() => assertTransition('ready', 'demonstrated')).toThrow(
      'A demonstrated PoC requires an outcome',
    );
  });

  it('requires a positive estimate and start before demo', () => {
    const validPlan = (service as any).validPlan.bind(service);
    expect(() =>
      validPlan(
        new Date('2026-08-14T08:00:00+07:00'),
        new Date('2026-08-15T12:00:00+07:00'),
        12,
      ),
    ).not.toThrow();
    expect(() =>
      validPlan(
        new Date('2026-08-15T12:00:00+07:00'),
        new Date('2026-08-15T12:00:00+07:00'),
        12,
      ),
    ).toThrow(BadRequestException);
    expect(() =>
      validPlan(
        new Date('2026-08-14T08:00:00+07:00'),
        new Date('2026-08-15T12:00:00+07:00'),
        0,
      ),
    ).toThrow(BadRequestException);
  });

  it('generates a stable operational display code format', () => {
    const code = (service as any).code(
      'Minh Châu',
      'Phạm Ngọc Duy',
      'web_app',
      '18',
      new Date('2026-08-15T12:00:00+07:00'),
    );
    expect(code).toMatch(/^MC\.PND-WA-P0018-1200-15\.08\.26$/);
  });
});
