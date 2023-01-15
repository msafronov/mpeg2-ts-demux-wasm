const { getInstance } = require('./utils');

describe('malloc', () => {
  describe('memory management', () => {
    it('should be zero', async () => {
      const instance = await getInstance();
      
      instance.exports.malloc(0);
  
      expect(instance.exports.memory.buffer.byteLength).toBe(0);
    });

    // segment (1) + metadata (1) + video (1)
    it('should be 3 memory blocks even if just 1 byte is allocated', async () => {
      const instance = await getInstance();
      
      instance.exports.malloc(1);
  
      expect(instance.exports.memory.buffer.byteLength).toBe(196608);
    });

    // segment (1) + metadata (1) + video (1)
    it('should be 3 memory blocks', async () => {
      const instance = await getInstance();
      
      instance.exports.malloc(65535);
  
      expect(instance.exports.memory.buffer.byteLength).toBe(196608);
    });

    // segment (1) + metadata (1) + video (1)
    it('should be 3 memory blocks (corner case)', async () => {
      const instance = await getInstance();
      
      instance.exports.malloc(65536);
  
      expect(instance.exports.memory.buffer.byteLength).toBe(196608);
    });

    // segment (1) + metadata (1) + video (1)
    it('should not decrease memory blocks after twice malloc', async () => {
      const instance = await getInstance();
      
      instance.exports.malloc(1);
      instance.exports.malloc(0);
  
      expect(instance.exports.memory.buffer.byteLength).toBe(196608);
    });

    // segment (2) + metadata (1) + video (2)
    it('should increase memory blocks after twice malloc correctly', async () => {
      const instance = await getInstance();
      
      instance.exports.malloc(1);
      instance.exports.malloc(70000);
  
      expect(instance.exports.memory.buffer.byteLength).toBe(327680);
    });
  });

  describe('offsets', () => {
    it('should not change s_offset', async () => {
      const instance = await getInstance();
      const previousOffset = instance.exports.s_offset.value;

      instance.exports.malloc(1);
  
      expect(instance.exports.s_offset.value).toBe(previousOffset);
    });

    // s_offset (0) -> m_offset (1) -> es_offset (2)
    it('should increase m_offset by 2', async () => {
      const instance = await getInstance();

      instance.exports.malloc(1);
  
      expect(instance.exports.m_offset.value).toBe(65536);
    });

    // s_offset (0) -> m_offset (1) -> es_offset (2)
    it('should increase es_offset by 2', async () => {
      const instance = await getInstance();

      instance.exports.malloc(1);
  
      expect(instance.exports.es_offset.value).toBe(131072);
    });

    // s_offset (0) -> m_offset (2) -> es_offset (3)
    it('should increase es_offset by 3', async () => {
      const instance = await getInstance();

      instance.exports.malloc(70000);
  
      expect(instance.exports.es_offset.value).toBe(196608);
    });

    // s_offset (0) -> m_offset (6) -> es_offset (7)
    it('should increase es_offset by 7 (corner case)', async () => {
      const instance = await getInstance();

      instance.exports.malloc(393216);
  
      expect(instance.exports.es_offset.value).toBe(458752);
    });

    // s_offset (0) -> m_offset (7) -> es_offset (9)
    it('should increase es_offset by 8', async () => {
      const instance = await getInstance();

      instance.exports.malloc(400000);
  
      expect(instance.exports.es_offset.value).toBe(589824);
    });

    // s_offset (0) -> m_offset (2) -> es_offset (3)
    it('should increase es_offset by 3 after twice malloc', async () => {
      const instance = await getInstance();

      instance.exports.malloc(1);
      instance.exports.malloc(70000);
  
      expect(instance.exports.es_offset.value).toBe(196608);
    });
  });

  describe('lengths', () => {
    it('should set s_len correctly after malloc', async () => {
      const instance = await getInstance();

      instance.exports.malloc(70000);
  
      expect(instance.exports.s_len.value).toBe(70000);
    });

    it('should set s_len correctly after twice malloc (increase)', async () => {
      const instance = await getInstance();

      instance.exports.malloc(70000);
      instance.exports.malloc(140000);
  
      expect(instance.exports.s_len.value).toBe(140000);
    });

    it('should set s_len correctly after twice malloc (decrease)', async () => {
      const instance = await getInstance();

      instance.exports.malloc(70000);
      instance.exports.malloc(20000);
  
      expect(instance.exports.s_len.value).toBe(20000);
    });

    it('should set nonzero m_len to zero after malloc', async () => {
      const instance = await getInstance();

      instance.exports.es_len.value = 65536;

      instance.exports.malloc(1);
  
      expect(instance.exports.m_len.value).toBe(0);
    });

    it('should set nonzero es_len to zero after malloc', async () => {
      const instance = await getInstance();

      instance.exports.es_len.value = 65536;

      instance.exports.malloc(1);
  
      expect(instance.exports.es_len.value).toBe(0);
    });
  });
});