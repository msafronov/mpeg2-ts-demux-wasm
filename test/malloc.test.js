const { getInstance } = require('./utils');

describe('malloc', () => {
  describe('memory management', () => {
    it('should be zero', async () => {
      const instance = await getInstance();
      
      instance.exports.malloc(0);
  
      expect(instance.exports.memory.buffer.byteLength).toBe(0);
    });
  
    it('should be 3 memory blocks even if just 1 byte is allocated', async () => {
      const instance = await getInstance();
      
      instance.exports.malloc(1);
  
      expect(instance.exports.memory.buffer.byteLength).toBe(196608);
    });
  
    it('should be 3 memory blocks', async () => {
      const instance = await getInstance();
      
      instance.exports.malloc(65535);
  
      expect(instance.exports.memory.buffer.byteLength).toBe(196608);
    });
  
    it('should be 3 memory blocks (corner case)', async () => {
      const instance = await getInstance();
      
      instance.exports.malloc(65536);
  
      expect(instance.exports.memory.buffer.byteLength).toBe(196608);
    });
  
    it('should not decrease memory blocks after twice malloc', async () => {
      const instance = await getInstance();
      
      instance.exports.malloc(1);
      instance.exports.malloc(0);
  
      expect(instance.exports.memory.buffer.byteLength).toBe(196608);
    });
  
    it('should increase memory blocks after twice malloc correctly', async () => {
      const instance = await getInstance();
      
      instance.exports.malloc(1);
      instance.exports.malloc(70000);
  
      expect(instance.exports.memory.buffer.byteLength).toBe(393216);
    });
  });

  describe('offsets', () => {
    it('should not change s_offset', async () => {
      const instance = await getInstance();
      const previousOffset = instance.exports.s_offset.value;

      instance.exports.malloc(1);
  
      expect(instance.exports.s_offset.value).toBe(previousOffset);
    });

    it('should increase v_es_offset by 1', async () => {
      const instance = await getInstance();

      instance.exports.malloc(1);
  
      expect(instance.exports.v_es_offset.value).toBe(65536);
    });

    it('should increase v_es_offset by 2', async () => {
      const instance = await getInstance();

      instance.exports.malloc(70000);
  
      expect(instance.exports.v_es_offset.value).toBe(131072);
    });

    it('should increase a_es_offset by 2', async () => {
      const instance = await getInstance();

      instance.exports.malloc(1);
  
      expect(instance.exports.a_es_offset.value).toBe(131072);
    });

    it('should increase a_es_offset by 2 (corner case)', async () => {
      const instance = await getInstance();

      instance.exports.malloc(65536);
  
      expect(instance.exports.a_es_offset.value).toBe(131072);
    });

    it('should increase a_es_offset by 4', async () => {
      const instance = await getInstance();

      instance.exports.malloc(70000);
  
      expect(instance.exports.a_es_offset.value).toBe(262144);
    });

    it('should increase v_es_offset by 2 after twice malloc', async () => {
      const instance = await getInstance();

      instance.exports.malloc(1);
      instance.exports.malloc(70000);
  
      expect(instance.exports.v_es_offset.value).toBe(131072);
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

    it('should set nonzero v_es_len to zero after malloc', async () => {
      const instance = await getInstance();

      instance.exports.v_es_len.value = 65536;

      instance.exports.malloc(1);
  
      expect(instance.exports.v_es_len.value).toBe(0);
    });

    it('should set nonzero a_es_len to zero after malloc', async () => {
      const instance = await getInstance();

      instance.exports.a_es_len.value = 65536;

      instance.exports.malloc(1);
  
      expect(instance.exports.a_es_len.value).toBe(0);
    });
  });
});