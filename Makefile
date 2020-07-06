lint:
	@gem install --no-document --conservative rubocop && \
	rubocop -l

testsuite:
	ruby test/simple/simple-test.rb && \
	ruby test/redis/redis-test.rb
