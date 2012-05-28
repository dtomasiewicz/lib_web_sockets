require 'lib_web_sockets'
require 'minitest/autorun'

# tests the frame structure described in section 5.2
# TODO
#   invalid frame parse tests
#     - payload shorter than PL (at end of data)
#       should raise an error
#     - payload longer than PL
#       should return remainder of length = difference (no error)
#   to_s tests
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
    @v_noepl_mask = [0x072A, "\xFC\x9A\x54\x02", bin("\xBD\xD8\x17")].pack 'nA4A3'

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
    data = @v_noepl_nomask.dup
    frame, remainder = LibWebSockets::Frame.parse data

    # ensure data was not modified by the call
    assert_equal @v_noepl_nomask, data

    parse_tests frame, remainder,
      :fin? => true,
      :rsv => [false, false, false],
      :op => :text,
      :masking_key => nil,
      :payload => bin("ABC")
  end


  def test_parse_noepl_mask
    data = @v_noepl_mask.dup
    frame, remainder = LibWebSockets::Frame.parse data

    # ensure data was not modified by the call
    assert_equal @v_noepl_mask, data

    parse_tests frame, remainder,
      :fin? => false,
      :rsv => [true, false, true],
      :op => :binary,
      :masking_key => "\xFC\x9A\x54\x02",
      :payload => bin("ABC"),
  end

  def test_parse_epl16_nomask
    data = @v_epl16_nomask.dup
    frame, remainder = LibWebSockets::Frame.parse data

    # ensure data was not modified by the call
    assert_equal @v_epl16_nomask, data

    parse_tests frame, remainder,
      :fin? => false,
      :rsv => [true, false, true],
      :op => :continue,
      :masking_key => nil,
      :payload => bin("ABC")*14011
  end

  def test_parse_epl64_mask
    data = @v_epl64_mask.dup
    frame, remainder = LibWebSockets::Frame.parse data

    # ensure data was not modified by the call
    assert_equal @v_epl64_mask, data

    parse_tests frame, remainder,
      :fin? => true,
      :rsv => [true, true, false],
      :op => :close,
      :masking_key => "\xA1\xE5\xB9\xDC",
      :payload => bin("BD9:")*24587
  end

  private

  def parse_tests(frame, remainder, exps = {})
    # invariants
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

  def assert_binary(str, msg = nil)
    assert_equal 'ASCII-8BIT', str.encoding.name, msg
  end

  def bin(str)
    str.dup.force_encoding 'ASCII-8BIT'
  end

end