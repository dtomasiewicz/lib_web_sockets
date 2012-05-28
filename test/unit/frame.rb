require 'lib_web_sockets'
require 'minitest/autorun'

# tests the frame structure described in section 5.2
# TODO invalid frame parse tests
#   - payload shorter than PL (at end of data)
#     should raise an error
#   - payload longer than PL
#     should return remainder of length = difference (no error)
class FrameTest < MiniTest::Unit::TestCase

  def setup

    # VALID FRAME - no EPL, no mask
    #         54   3  21
    #   0000011000010001
    #        x06     x11
    #
    #   (1) FIN = 1
    #   (2) RSV 321 = 000
    #   (3) OPCODE = 0001 (text)
    #   (4) MASK = 0
    #   (5) PAYLOAD LEN = 0000011 (3)
    # 
    # PAYLOAD = "ABC"
    @v_noepl_nomask = [0x0611, bin("ABC")].pack 'nA3'

    # VALID FRAME - no EPL, with mask
    #         54   3  21
    #   0000011100101010
    #        x07     x2A
    #
    #   (1) FIN = 0
    #   (2) RSV 321 = 101
    #   (3) OPCODE = 0010 (binary)
    #   (4) MASK = 1
    #   (5) PAYLOAD LEN = 0000011 (3)
    # 
    # MASKING KEY = "\xFC\x9A\x54\x02" (4237972482)
    # PAYLOAD = "ABC" ("\x41\x42\x43")
    # MASKED PAYLOAD = "\xBD\xD8\x17"
    @v_noepl_mask = [0x071A, "\xFC\x9A\x54\x02", bin("\xBD\xD8\x17")].pack 'nA4A3'

    # VALID FRAME - 16-bit EPL, no mask
    #         54   3  21
    #   1111110000001010
    #        xFC     x0A
    #
    #   (1) FIN = 0
    #   (2) RSV 321 = 101
    #   (3) OPCODE = 0000 (continue)
    #   (4) MASK = 0
    #   (5) PAYLOAD LEN = 1111110 (126)
    # 
    # EXTENDED PAYLOAD LENGTH = 42033
    # PAYLOAD = "ABC" * 14011
    @v_epl16_nomask = [0xFC0A, 42033, bin("ABC")*14011].pack 'nnA42033'

    # VALID FRAME - 64-bit EPL, with mask
    #         54   3  21
    #   1111111110000111
    #        xFF     x87
    #
    #   (1) FIN = 1
    #   (2) RSV 321 = 011
    #   (3) OPCODE = 1000 (close)
    #   (4) MASK = 1
    #   (5) PAYLOAD LEN = 1111111 (127)
    # 
    # EXTENDED PAYLOAD LENGTH = 98348
    # MASKING KEY = "\xA1\xE5\xB9\xDC" (2716187100)
    # PAYLOAD = "BD9:" ("\x42\x44\x39\x3A") * 24587
    # MASKED PAYLOAD = "\xE3\xA1\x80\xE6" * 24587
    @v_epl64_mask = [0xFF87, 98348, "\xA1\xE5\xB9\xDC",
      bin("\xE3\xA1\x80\xE6")*24587].pack 'nQ>A4A98348'

  end


  def test_parse_noepl_nomask
    frame, remainder = LibWebSockets::Frame.parse @v_noepl_nomask

    assert_equal 0, remainder.length
    assert_binary frame.payload
    assert_binary remainder
    assert_equal bin("ABC"), frame.payload
    assert !frame.masked?
    assert_nil frame.masking_key
  end


  def test_parse_noepl_mask
    frame, remainder = LibWebSockets::Frame.parse @v_noepl_mask

    assert_equal 0, remainder.length
    assert_binary frame.payload
    assert_binary remainder
    assert_equal bin("ABC"), frame.payload
    assert frame.masked?
    assert_equal "\xFC\x9A\x54\x02", frame.masking_key
  end

  def test_parse_epl16_nomask
    frame, remainder = LibWebSockets::Frame.parse @v_epl16_nomask

    assert_equal 0, remainder.length
    assert_binary frame.payload
    assert_binary remainder
    assert_equal bin("ABC")*14011, frame.payload
    assert !frame.masked?
    assert_nil frame.masking_key
  end

  def test_parse_epl64_mask
    frame, remainder = LibWebSockets::Frame.parse @v_epl64_mask

    assert_equal 0, remainder.length
    assert_binary frame.payload
    assert_binary remainder
    assert_equal bin("BD9:")*24587, frame.payload
    assert frame.masked?
    assert_equal "\xA1\xE5\xB9\xDC", frame.masking_key
  end

  private

  def assert_binary(str, msg = nil)
    assert_equal 'ASCII-8BIT', str.encoding.name, msg
  end

  def bin(str)
    str.dup.force_encoding 'ASCII-8BIT'
  end

end