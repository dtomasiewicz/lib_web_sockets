require 'lib_web_sockets'
require 'minitest/autorun'

# tests the frame structure described in section 5.2
# TODO
#   invalid frame parse tests
#     - payload shorter than PL (at end of data)
#       should raise an error
#     - payload longer than PL
#       should return remainder of length = difference (no error)
class FrameTest < MiniTest::Unit::TestCase

  # VALID FRAME - no EPL, no mask
  #   1000000100000011
  #        x81     x60
  #
  #   FIN = 1
  #   RSV 123 = 000
  #   OPCODE = 0001 (text)
  #   MASK = 0
  #   PAYLOAD LEN = 0000011 (3)
  # 
  # PAYLOAD = "ABC"
  def v_noepl_nomask
    [bin("\x81\x03"), bin("ABC")].pack 'A2A3'
  end

  def test_parse_v_noepl_nomask
    fw_test_parse v_noepl_nomask,
      :fin? => true,
      :rsv => [false, false, false],
      :op => :text,
      :masking_key => nil,
      :payload => bin("ABC")
  end

  def test_to_s_v_noepl_nomask
    fw_test_to_s v_noepl_nomask,
      :text,
      bin("ABC"),
      true
  end

  # VALID FRAME - no EPL, with mask
  #   0101001010000011
  #        x52     x83
  #
  #   FIN = 0
  #   RSV 123 = 101
  #   OPCODE = 0010 (binary)
  #   MASK = 1
  #   PAYLOAD LEN = 0000011 (3)
  # 
  # MASKING KEY = "\xFC\x9A\x54\x02" (4237972482)
  # PAYLOAD = "ABC" ("\x41\x42\x43")
  # MASKED PAYLOAD = "\xBD\xD8\x17"
  def v_noepl_mask
    [bin("\x52\x83"), bin("\xFC\x9A\x54\x02"), bin("\xBD\xD8\x17")].pack 'A2A4A3'
  end

  def test_parse_v_noepl_mask
    fw_test_parse v_noepl_mask,
      :fin? => false,
      :rsv => [true, false, true],
      :op => :binary,
      :masking_key => bin("\xFC\x9A\x54\x02"),
      :payload => bin("ABC"),
  end

  def test_to_s_v_noepl_mask
    fw_test_to_s v_noepl_mask,
      :binary,
      bin("ABC"),
      false,
      :rsv1 => true,
      :rsv2 => false,
      :rsv3 => true,
      :masking_key => bin("\xFC\x9A\x54\x02")
  end

  # VALID FRAME - 16-bit EPL, no mask
  #   0101000001111110
  #        x50     x7E
  #
  #   FIN = 0
  #   RSV 123 = 101
  #   OPCODE = 0000 (continue)
  #   MASK = 0
  #   PAYLOAD LEN = 1111110 (126)
  # 
  # EXTENDED PAYLOAD LENGTH = 42033
  # PAYLOAD = "ABC" * 14011
  def v_epl16_nomask
    [bin("\x50\x7E"), 42033, bin("ABC")*14011].pack 'A2nA42033'
  end

  def test_parse_v_epl16_nomask
    fw_test_parse v_epl16_nomask,
      :fin? => false,
      :rsv => [true, false, true],
      :op => :continue,
      :masking_key => nil,
      :payload => bin("ABC")*14011
  end

  def test_to_s_v_epl16_nomask
    fw_test_to_s v_epl16_nomask,
      :continue,
      bin("ABC")*14011,
      false,
      :rsv1 => true,
      :rsv2 => false,
      :rsv3 => true
  end

  # VALID FRAME - 64-bit EPL, with mask
  #   1110100011111111
  #        xE8     xFF
  #
  #   FIN = 1
  #   RSV 123 = 110
  #   OPCODE = 1000 (close)
  #   MASK = 1
  #   PAYLOAD LEN = 1111111 (127)
  # 
  # EXTENDED PAYLOAD LENGTH = 98348
  # MASKING KEY = "\xA1\xE5\xB9\xDC" (2716187100)
  # PAYLOAD = "BD9:" ("\x42\x44\x39\x3A") * 24587
  # MASKED PAYLOAD = "\xE3\xA1\x80\xE6" * 24587
  def v_epl64_mask
    [bin("\xE8\xFF"), 98348, bin("\xA1\xE5\xB9\xDC"), bin("\xE3\xA1\x80\xE6")*24587].pack 'A2Q>A4A98348'
  end

  def test_parse_v_epl64_mask
    fw_test_parse v_epl64_mask,
      :fin? => true,
      :rsv => [true, true, false],
      :op => :close,
      :masking_key => bin("\xA1\xE5\xB9\xDC"),
      :payload => bin("BD9:")*24587
  end

  def test_to_s_v_epl64_mask
    fw_test_to_s v_epl64_mask,
      :close,
      bin("BD9:")*24587,
      true,
      :rsv1 => true,
      :rsv2 => true,
      :rsv3 => false,
      :masking_key => bin("\xA1\xE5\xB9\xDC")
  end

  # TODO more like above

  private

  # framework for test_parse_* tests
  def fw_test_parse(data, exps = {})
    data_cpy = data.dup
    frame, remainder = LibWebSockets::Frame.parse data_cpy

    # invariants
    assert_equal data, data_cpy # call didn't modify the data
    assert_binary frame.payload
    assert_binary remainder

    if exps.has_key? :fin?
      assert_equal !!exps[:fin?], !!frame.fin?
    end

    if exps.has_key? :rsv
      assert_equal exps[:rsv], [frame.rsv1, frame.rsv2, frame.rsv3]
    end

    if exps.has_key? :op
      assert_equal exps[:op], frame.op
    end

    if exps.has_key? :masking_key
      assert_equal exps[:masking_key], frame.masking_key
      assert_equal !!frame.masked?, !!exps[:masking_key]
    end

    if exps.has_key? :payload
      assert_equal exps[:payload], frame.payload
    end

    if exps.has_key? :remainder
      assert_equal exps[:remainder], remainder
    else
      assert_equal bin(""), remainder
    end
  end

  def fw_test_to_s(expected, op, payload, fin, extra = {})
    payload_cpy = payload.dup
    data = LibWebSockets::Frame.new(op, payload_cpy, fin, extra).to_s
    assert_binary data
    assert_equal expected, data
    assert_equal payload, payload_cpy # ensure payload not modified
  end

  def assert_binary(str, msg = nil)
    assert_equal 'ASCII-8BIT', str.encoding.name, msg
  end

  def bin(str)
    str.encoding.name == 'ASCII-8BIT' ? str : str.dup.force_encoding('ASCII-8BIT')
  end

end