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

require 'async/wrapper'

require 'sequel/adapters/postgres'

module Async
	module Sequel
		module Postgres
			class Adapter < Wrapper
				def initialize(database, connection_specification, reactor = nil)
					@connection = ::Sequel::Postgres::Adapter.connect_start(connection_specification)
					
					@db = database
					@connection.instance_variable_set(:@db, database)
					@connection.instance_variable_set(:@prepared_statements, {})
					
					super(@connection.socket_io, reactor)
					
					status = @connection.connect_poll
					
					while true
						if status == PG::PGRES_POLLING_FAILED
							raise PG::Error.new(@connection.error_message)
						elsif status == PG::PGRES_POLLING_READING
							self.wait_readable
						elsif(status == PG::PGRES_POLLING_WRITING)
							self.wait_writable
						elsif status == PG::PGRES_POLLING_OK
							break
						end
						
						status = @connection.connect_poll
					end
				end
				
				def async_exec(*args)
					@connection.send_query(*args)
					last_result = result = true
					
					Async.logger.info(self) {args}
					
					while true
						wait_readable
						
						@connection.consume_input
						
						while @connection.is_busy == false
							if result = @connection.get_result
								last_result = result
								
								yield result if block_given?
							else
								return last_result
							end
						end
					end
				ensure
					result = @connection.get_result until result.nil?
				end
				
				alias exec async_exec
				alias exec_params exec
				
				# Execute the given SQL with this connection.  If a block is given,
				# yield the results, otherwise, return the number of changed rows.
				def execute(sql, args=nil)
					args = args.map{|v| @db.bound_variable_arg(v, self)} if args
					q = check_disconnect_errors{execute_query(sql, args)}
					begin
						block_given? ? yield(q) : q.cmd_tuples
					ensure
						q.clear if q && q.respond_to?(:clear)
					end
				end
				
				# Return the PGResult containing the query results.
				def execute_query(sql, args)
					@db.log_connection_yield(sql, self, args){args ? self.async_exec(sql, args) : self.async_exec(sql)}
				end
				
				def respond_to?(*args)
					@connection.respond_to?(*args)
				end
				
				def method_missing(*args, &block)
					# Async.logger.info(self) {args}
					
					@connection.send(*args, &block)
				end
			end
		end
	end
end
