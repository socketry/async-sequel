
require 'async'

require 'sequel'
require_relative '../../lib/async/sequel/postgres/database'
require_relative '../../lib/async/sequel/connection_pool/fibered'

Async.logger.info!

Async do
	db = Sequel.connect(adapter: Async::Sequel::Postgres::Database, host: "localhost", user: "samuel", database: "rubygems", pool_class: Async::Sequel::ConnectionPool::Fibered)
	
	query = db.select{pg_sleep(1)}
	
	10.times do
		Async do |task|
			while true
				Async.logger.info("query", query.to_a)
			end
		end
	end
ensure
	db&.disconnect
end

Async.logger.info("Done")