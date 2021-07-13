# frozen-string-literal: true

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

require 'async/notification'

require 'sequel/connection_pool'

module Async
	module Sequel
		module ConnectionPool
			class Fibered < ::Sequel::ConnectionPool
				def initialize(database, options = ::Sequel::OPTS)
					@limit = @options.delete(:limit)
					super(database, options)
					
					@database = database
					@options = options
					
					@resources = []
					@available = Async::Notification.new
					
					@active = 0
				end
				
				attr :resources
				
				def hold(server = nil, &block)
					acquire(&block)
				end
				
				def disconnect(server = nil)
					self.close
				end
				
				def servers
					[:default]
				end
				
				def size
					@active
				end
				
				def max_size
					@limit
				end
				
				def empty?
					@resources.empty?
				end
				
				def acquire
					resource = wait_for_resource
					
					return resource unless block_given?
					
					begin
						yield resource
					ensure
						release(resource)
					end
				end
				
				# Make the resource resources and let waiting tasks know that there is something resources.
				def release(resource)
					# A resource that is not good should also not be reusable.
					# unless resource.closed?
						reuse(resource)
					# else
					# 	retire(resource)
					# end
				end
				
				def close
					@resources.each(&:close)
					@resources.clear
					
					@active = 0
				end
				
				def to_s
					"\#<#{self.class} resources=#{resources.size} limit=#{@limit}>"
				end
				
				protected
				
				def reuse(resource)
					Async.logger.debug(self) {"Reuse #{resource}"}
					
					@resources << resource
					
					@available.signal
				end
				
				def retire(resource)
					Async.logger.debug(self) {"Retire #{resource}"}
					
					@active -= 1
					
					resource.close
					
					@available.signal
				end
				
				def wait_for_resource
					# If we fail to create a resource (below), we will end up waiting for one to become resources.
					until resource = available_resource
						@available.wait
					end
					
					Async.logger.debug(self) {"Wait for resource #{resource}"}
					
					return resource
				end
				
				def available_resource
					while resource = @resources.pop
						# if resource.connected?
							return resource
						# else
						# 	retire(resource)
						# end
					end
					
					if @limit.nil? or @active < @limit
						Async.logger.debug(self) {"No resources resources, allocating new one..."}
						
						@active += 1
						
						return make_new(:default)
					end
					
					return nil
				end
			end
		end
	end
end
