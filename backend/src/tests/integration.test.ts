import { describe, it, expect } from 'vitest';
import request from 'supertest';

// Testujemy działającą aplikację (Backend musi być uruchomiony w tle!)
const API_URL = 'http://localhost:3000';

describe('Testy Integracyjne (Backend + Baza Danych)', () => {
  
  // Test 1: Sprawdzenie endpointu Health Check
  it('GET /health powinien zwrócić status 200', async () => {
    const res = await request(API_URL).get('/health');
    
    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.service).toBe('crownhike-api');
  });

  // Test 2: Sprawdzenie połączenia z bazą danych (INTEGRACJA)
  it('GET /db-health powinien potwierdzić połączenie z bazą', async () => {
    const res = await request(API_URL).get('/db-health');

    // Sprawdzamy czy API odpowiedziało 200
    expect(res.status).toBe(200);
    
    // Sprawdzamy czy w body jest flaga ok: true
    expect(res.body.ok).toBe(true);
    
    // Sprawdzamy czy baza zwróciła wynik (tablicę)
    // To dowodzi, że query 'SELECT 1' zadziałało
    expect(Array.isArray(res.body.db)).toBe(true);
  });
});