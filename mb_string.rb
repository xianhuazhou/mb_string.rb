#!/usr/bin/env ruby
=begin
	string extension, can use it for gb2312, gbk, big5, utf-8...multibyte charset.
	@author: xianhua.zhou@gmail.com
	@date: 2006.09.11
	@modify: 2006.09.14
	@version: 0.2
	
	Change Log:
	
	0.2: 
	    修正字符编码的检测错误，目前支持ascii, gb2312, gbk, big5, gb18030编码
		
	0.1: 
	    发布0.1版
=end
require 'iconv'
require 'cgi'
class String 

	#return part of string
	# offset: start position
	# length: limit length from offset
	# example: 'abcd'.mb_sub(1, 3)  =>  bcd
	# example: '上中a下'.mb_sub(1, 3)  =>  中a下
	# example: '上中a下'.mb_sub(0, 2, '...')  =>  上中...
	def mb_sub(offset, length, append = '')
		offset, length = offset.to_i, length.to_i
		return '' if length < 0
		string = mb_to_arr
		offset += string.size if offset < 0
		append = '...' if offset + length < string.size and append != ''
		string[offset...(offset + length)].join + append
	end

	#return string length
	# example: 'abcd'.mb_size  =>  4
	# example: '上中下cd'.mb_size  =>  5
	def mb_size;mb_to_arr.size;end
	def mb_length;mb_size;end

	#return string in reverse order
	# example: 'abc'.mb_reverse  =>  cba
	# example: '上中下abc'.mb_reverse  =>  cba下中上
	def mb_reverse;mb_to_arr.reverse.join;end

	#shuffle string
	# example: 'abcd'.mb_shuffle  =>  dcab
	# example: 'abcd上中下'.mb_shuffle  =>  中上b下dca
	def mb_shuffle
		_arr = mb_to_arr
		r = 0
		0.upto(_arr.size - 1) {|i|
			r = (rand i).to_i
			_arr[r], _arr[i] = _arr[i], _arr[r]
		}
		_arr.join
	end

	#convert to utf8
	# 'gbk' is the default string charset
	# :charset  string  string charset
	# :cstyle  boolean  output c language style
	# example 'abc'.mb_utf8  =>  97 98 99
	# example '上中下'.mb_utf8(:charset => 'utf-8')  =>  e4b8ad e59bbd e4baba 
	# example '上中下'.mb_utf8(:cstyle => true)  =>  \344\270\255\345\233\275\344\272\272 
	def mb_utf8(opt = {})
		_arr = mb_to_arr
		if opt[:charset].to_s != ''
			_arr = _mb_to_charset(_arr, opt[:charset], 'utf-8')
		end
		tmp = ''
		format = opt[:cstyle] ? '\\%o' : '%x'
		0.upto(_arr.size - 1) {|i|
			if _arr[i].size == 1
				_arr[i] = opt[:cstyle] ? '\\' + _arr[i][0].to_s : _arr[i][0]
				next
			end
			tmp = ''
			_arr[i].each_byte {|c| tmp << sprintf(format, c) if c > 0}
			_arr[i] = tmp
		}
		_arr.join((opt[:cstyle] ? '' : ' '))
	end

	#convert string like &#x4E0A;  'gbk' is the default string charset
	# :charset  string  source string charset
	# :java_style  boolean  output java language style
	# example: 'abc'.mb_hex  =>  &#x61;&#x62;&#x63;
	# example: '上中下'.mb_hex(:charset => 'utf-8')  =>  &#x4e0a;&#x4e2d;&#x4e0b;
	# example: '上中下'.mb_hex(:charset => 'utf-8', :java_style => true)  => 
	#							\u4e0a\u4e2d\u4e0b
	def mb_hex(opt = {});_mb_num_code(opt[:charset], 16, opt[:java_style]);end

	#convert string like &#19978;  'gbk' is the default string charset
	# :charset  string  source string charset
	# example: 'abc'.mb_dec  =>  '&#97;&#98;&#99;'
	# example: '上中下'.mb_dec(:charset => 'utf-8')  =>  &#19978;&#20013;&#19979;
	def mb_dec(opt = {});_mb_num_code(opt[:charset], 10);end

	#get string zone code
	# example: '上中下'.mb_zone  =>  4147 5448 4734
	def mb_zone
		_arr = mb_to_arr
		0.upto(_arr.size - 1) {|i|
			if _arr[i][0] < 0x80
				_arr[i] = _arr[i][0]
				next
			end
			_arr[i] = Iconv.new('gbk', 'utf-8').iconv(_arr[i]) if @is_utf8
			_arr[i] = sprintf('%d', _arr[i][0] - 0xA0) + sprintf('%d', _arr[i][1] - 0xA0)
		}	
		_arr.join(' ')
	end

	#convert string to array
	# example: 'abcd'.mb_to_arr =>  ['a', 'b', 'c', 'd']
	# example: '上中下ab'.mb_to_arr  =>  ['上', '中', '下', 'a', 'b']
	def mb_to_arr
		str = to_s
		
		#utf8
		@_utf8_charset = /\A(?:
		[\x00-\x7f]                                     |
		[\xc2-\xdf] [\x80-\xbf]                         |
		\xe0        [\xa0-\xbf] [\x80-\xbf]             |
		[\xe1-\xef] [\x80-\xbf] [\x80-\xbf]             |
		\xf0        [\x90-\xbf] [\x80-\xbf] [\x80-\xbf] |
		[\xf1-\xf3] [\x80-\xbf] [\x80-\xbf] [\x80-\xbf] |
		\xf4        [\x80-\x8f] [\x80-\xbf] [\x80-\xbf]
		)*\z/nx
		
		#gb2312 gbk big5 gb18030
		@_asia_charset = /\A(?:
		[\xb0-\xf7] [\xa0-\xfe]                         |
		
		[\x81-\xfe] [\x40-\xfe]                         |
		
		[\xa1-\xf9] [\x40-\x7e\xa1-\xfe]                |
		
		[\x81-\xfe] [\x40-\x7e\x80-\xfe]                |
		[\x81-\xfe] [\x30-\x39] [\x81-\xfe] [\x30-\x39]	
		)*\z/nx

		@is_utf8 = @_utf8_charset.match(str) ? true : false
		arr = []
		i = 0
		tmp_str = ''
		if @is_utf8
			while i < size
				tmp_str = ''
				4.times {
					tmp_str << str[i].chr;i += 1
					break if @_utf8_charset.match(tmp_str)
				}
				arr << tmp_str
			end
		else
			while i < size
				if str[i] < 0x80
					arr << str[i].chr;i += 1;next
				end
				tmp_str = ''
				4.times {
					tmp_str << str[i].chr
					i += 1
					break if @_asia_charset.match(tmp_str)
				}
				arr << tmp_str
			end
		end
		@_utf8_charset = @_asia_charset = nil
		arr
	end

	#"escape" family function as same as "CGI.escape".
	def escape;CGI.unescape(self);end
	def unescape;CGI.unescape(self);end
	def escapeHTML;CGI.escapeHTML(self);end
	def unescapeHTML;CGI.unescapeHTML(self);end

	private
	#get unicode infomaction
	def _mb_num_code(charset, num_code, java_style = false)
		from = 'gbk' if from.to_s == ''
		_arr = _mb_to_charset(mb_to_arr, charset, 'unicode')
		_prefix, _end = '&#', ';'
		if num_code == 16
			if java_style
				_prefix, _end = '\\u', ''
			else
				_prefix, _end = '&#x', ';'
			end
			0.upto(_arr.size - 1) {|i|
				if _arr[i][3].to_i == 0
					_arr[i] = _prefix + sprintf('%x', _arr[i][2]) + _end
				else
					_arr[i] = _prefix + (sprintf('%2x', _arr[i][3]) + sprintf('%2x', _arr[i][2])).gsub(' ', '0') + _end
				end
			}
		elsif num_code == 10
			0.upto(_arr.size - 1) {|i|
				if _arr[i][3].to_i == 0
					_arr[i] = _prefix + _arr[i][2].to_s + _end
				else
					_arr[i] = _prefix + (sprintf('%2x', _arr[i][3]) + sprintf('%2x', _arr[i][2])).gsub(' ', '0').hex.to_s + _end
				end
			}
		end
		_arr.join
	end

	#convert charset fro arr
	def _mb_to_charset(arr, from, to)
		begin
			0.upto(arr.size - 1) {|i|
				arr[i] = Iconv.new(to, from).iconv(arr[i])
			}
		rescue Exception => e
		end
		arr
	end
end
