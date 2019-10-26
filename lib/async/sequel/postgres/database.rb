# Copyright, 2019, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require_relative 'adapter'

require 'sequel/adapters/postgres'

module Async
	module Sequel
		module Postgres
			class Database < ::Sequel::Postgres::Database
				def connect(server)
					opts = server_opts(server)
					
					connection_params = {
						:host => opts[:host],
						:port => opts[:port],
						:dbname => opts[:database],
						:user => opts[:user],
						:password => opts[:password],
						:connect_timeout => opts[:connect_timeout] || 20,
						:sslmode => opts[:sslmode],
						:sslrootcert => opts[:sslrootcert]
					}.delete_if { |key, value| blank_object?(value) }
					
					connection_params.merge!(opts[:driver_options]) if opts[:driver_options]
					conn = Adapter.new(self, opts[:conn_str] || connection_params)

					if receiver = opts[:notice_receiver]
						conn.set_notice_receiver(&receiver)
					end
					
					if conn.respond_to?(:type_map_for_queries=) && defined?(self::PG_QUERY_TYPE_MAP)
						conn.type_map_for_queries = self::PG_QUERY_TYPE_MAP
					end

					if encoding = opts[:encoding] || opts[:charset]
						if conn.respond_to?(:set_client_encoding)
							conn.set_client_encoding(encoding)
						else
							conn.async_exec("set client_encoding to '#{encoding}'")
						end
					end

					connection_configuration_sqls(opts).each{|sql| conn.execute(sql)}
					conn
				end
			end
		end
	end
end
