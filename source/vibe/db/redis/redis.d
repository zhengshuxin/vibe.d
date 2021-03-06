/**
	Redis database client implementation.

	Copyright: © 2012-2014 RejectedSoftware e.K.
	License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	Authors: Jan Krüger
*/
module vibe.db.redis.redis;

public import vibe.core.net;

import vibe.core.connectionpool;
import vibe.core.log;
import vibe.stream.operations;
import std.conv;
import std.exception;
import std.format;
import std.range : isOutputRange;
import std.string;
import std.traits;
import std.utf;

// TODO: convert RedisReply to expose an input range interface


/**
	Returns a RedisClient that can be used to communicate to the specified database server.
*/
RedisClient connectRedis(string host, ushort port = 6379)
{
	return new RedisClient(host, port);
}


/**
	A redis client with connection pooling.
*/
final class RedisClient {
	private {
		ConnectionPool!RedisConnection m_connections;
		string m_authPassword;
		size_t m_selectedDB;
	}

	this(string host = "127.0.0.1", ushort port = 6379)
	{
		m_connections = new ConnectionPool!RedisConnection({
			return new RedisConnection(host, port);
		});
	}

	size_t del(string[] keys...) { return request!size_t("DEL", keys); }
	bool exists(string key) { return request!bool("EXISTS", key); }
	bool expire(string key, size_t seconds) { return request!bool("EXPIRE", key, seconds); }
	bool expireAt(string key, long timestamp) { return request!bool("EXPIREAT", key, timestamp); }
	RedisReply keys(string pattern) { return request("KEYS", pattern); }
	bool move(string key, string db) { return request!bool("MOVE", key, db); }
	bool persists(string key) { return request!bool("PERSISTS", key); }
	//TODO: object
	string randomKey() { return request!string("RANDOMKEY"); }
	void rename(string key, string newkey) { request("RENAME", key, newkey); }
	bool renameNX(string key, string newkey) { return request!bool("RENAMENX", key, newkey); }
	//TODO sort
	long ttl(string key) { return request!long("TTL", key); }
	string type(string key) { return request!string("TYPE", key); }
	//TODO eval

	/*
		String Commands
	*/

	size_t append(T : E[], E)(string key, T suffix) { return request!size_t("APPEND", key, suffix); }
	int decr(string key, int value = 1) { return value == 1 ? request!int("DECR", key) : request!int("DECRBY", key, value); }
	T get(T : E[], E)(string key) { return request!T("GET", key); }
	bool getBit(string key, size_t offset) { return request!bool("GETBIT", key, offset); }
	T getRange(T : E[], E)(string key, size_t start, size_t end) { return request!T("GETRANGE", start, end); }
	T getSet(T : E[], E)(string key, T value) { return request!T("GET", key, value); }
	int incr(string key, int value = 1) { return value == 1 ? request!int("INCR", key) : request!int("INCRBY", key, value); }
	RedisReply mget(string[] keys) { return request("MGET", keys); }
	
	void mset(ARGS...)(ARGS args)
	{
		static assert(ARGS.length % 2 == 0 && ARGS.length >= 2, "Arguments to mset must be pairs of key/value");
		foreach (i, T; ARGS ) static assert(i % 2 != 0 || is(T == string), "Keys must be strings.");
	    request("MSET", args);
	}

	bool msetNX(ARGS...)(ARGS args) {
		static assert(ARGS.length % 2 == 0 && ARGS.length >= 2, "Arguments to mset must be pairs of key/value");
		foreach (i, T; ARGS ) static assert(i % 2 != 0 || is(T == string), "Keys must be strings.");
	    return request!bool("MSETEX", args);
	}

	void set(T : E[], E)(string key, T value) { request("SET", key, value); }
	bool setBit(string key, size_t offset, bool value) { return request!bool("SETBIT", key, offset, value ? "1" : "0"); }
	void setEX(T : E[], E)(string key, size_t seconds, T value) { request("SETEX", key, seconds, value); }
	bool setNX(T : E[], E)(string key, T value) { return request!bool("SETNX", key, value); }
	size_t setRange(T : E[], E)(string key, size_t offset, T value) { return request!size_t("SETRANGE", key, offset, value); }
	size_t strlen(string key) { return request!size_t("STRLEN", key); }

	/*
		Hashes
	*/

	size_t hdel(string key, string[] fields...) { return request!size_t("HDEL", key, fields); }
	bool hexists(string key, string field) { return request!bool("HEXISTS", key, field); }
	void hset(T : E[], E)(string key, string field, T value) { request("HSET", key, field, value); }
	T hget(T : E[], E)(string key, string field) { return request!T("HGET", key, field); }
	RedisReply hgetAll(string key) { return request("HGETALL", key); }
	int hincr(string key, string field, int value=1) { return request!int("HINCRBY", key, field, value); }
	RedisReply hkeys(string key) { return request("HKEYS", key); }
	size_t hlen(string key) { return request!size_t("HLEN", key); }
	RedisReply hmget(string key, string[] fields...) { return request("HMGET", key, fields); }
	void hmset(ARGS...)(string key, ARGS args) { request("HMSET", key, args); }
	bool hmsetNX(ARGS...)(string key, ARGS args) { return request!bool("HMSET", key, args); }
	RedisReply hvals(string key) { return request("HVALS", key); }
	T lindex(T : E[], E)(string key, size_t index) { return request!T("LINDEX", key, index); }
	size_t linsertBefore(T1, T2)(string key, T1 pivot, T2 value) { return request!size_t("LINSERT", key, "BEFORE", pivot, value); }
	size_t linsertAfter(T1, T2)(string key, T1 pivot, T2 value) { return request!size_t("LINSERT", key, "AFTER", pivot, value); }
	size_t llen(string key) { return request!size_t("LLEN", key); }
	size_t lpush(ARGS...)(string key, ARGS args) { return request!size_t("LPUSH", key, args); }
	size_t lpushX(T)(string key, T value) { return request!size_t("LPUSHX", key, value); }
	size_t rpush(ARGS...)(string key, ARGS args) { return request!size_t("RPUSH", key, args); }
	size_t rpushX(T)(string key, T value) { return request!size_t("RPUSHX", key, value); }
	RedisReply lrange(string key, size_t start, size_t stop) { return request("LRANGE",  key, start, stop); }
	size_t lrem(T : E[], E)(string key, size_t count, T value) { return request!size_t("LREM", count, value); }
	void lset(T : E[], E)(string key, size_t index, T value) { request("LSET", key, index, value); }
	void ltrim(string key, size_t start, size_t stop) { request("LTRIM",  key, start, stop); }
	T rpop(T : E[], E)(string key) { return request!T("RPOP", key); }
	T lpop(T : E[], E)(string key) { return request!T("LPOP", key); }
	T rpoplpush(T : E[], E)(string key, string destination) { return request!T("RPOPLPUSH", key, destination); }

	/*
		Sets
	*/

	size_t sadd(ARGS...)(string key, ARGS args) { return request!size_t("SADD", key, args); }
	size_t scard(string key) { return request!size_t("SCARD", key); }
	RedisReply sdiff(string[] keys...) { return request("SDIFF", keys); }
	size_t sdiffStore(string destination, string[] keys...) { return request!size_t("SDIFFSTORE", destination, keys); }
	RedisReply sinter(string[] keys) { return request("SINTER", keys); }
	size_t sinterStore(string destination, string[] keys...) { return request!size_t("SINTERSTORE", destination, keys); }
	bool sisMember(T : E[], E)(string key, T member) { return request!bool("SISMEMBER", key, member); }
	RedisReply smembers(string key) { return request("SMEMBERS", key); }
	bool smove(T : E[], E)(string source, string destination, T member) { return request!bool("SMOVE", source, destination, member); }
	T spop(T : E[], E)(string key) { return request!T("SPOP", key ); }
	T srandMember(T : E[], E)(string key) { return request!T("SRANDMEMBER", key ); }
	size_t srem(ARGS...)(string key, ARGS args) { return request!size_t("SREM", key, args); }
	RedisReply sunion(string[] keys...) { return request("SUNION", keys); }
	size_t sunionStore(string[] keys...) { return request!size_t("SUNIONSTORE", keys); }

	/*
		Sorted Sets
	*/

	size_t zadd(ARGS...)(string key, ARGS args) { return request!size_t("SADD", key, args); }
	size_t Zcard(string key) { return request!size_t("ZCARD", key); }
	size_t zcount(string key, double min, double max) { return request!size_t("ZCOUNT", key, min, max); }
	double zincrby(string key, double value, string member) { return request!double("ZINCRBY", value, member); }
	//TODO: zinterstore
	RedisReply zrange(string key, size_t start, size_t end, bool withScores=false) {
		string[] args = [key, to!string(start), to!string(end)];
		if (withScores) args ~= "WITHSCORES";
		return request("ZRANGE", args);
	}

	RedisReply zrangeByScore(string key, size_t start, size_t end, bool withScores=false) {
		string[] args = [key, to!string(start), to!string(end)];
		if (withScores) args ~= "WITHSCORES";
		return request("ZRANGEBYSCORE", args);
	}

	RedisReply zrangeByScore(string key, size_t start, size_t end, size_t offset, size_t count, bool withScores=false) {
		string[] args = [key, to!string(start), to!string(end)];
		if (withScores) args ~= "WITHSCORES";
		args ~= ["LIMIT", to!string(offset), to!string(count)];
		return request("ZRANGEBYSCORE", args);
	}

	int zrank(string key, string member) {
		auto str = request!string("ZRANK", key, member);
		return str ? parse!int(str) : -1;
	}
	size_t zrem(string key, string[] members...) { return request!size_t("ZREM", key, members); }
	size_t zremRangeByRank(string key, int start, int stop) { return request!size_t("ZREMRANGEBYRANK", key, start, stop); }
	size_t zremRangeByScore(string key, double min, double max) { return request!size_t("ZREMRANGEBYSCORE", key, min, max);}

	RedisReply zrevRange(string key, size_t start, size_t end, bool withScores=false) {
		string[] args = [key, to!string(start), to!string(end)];
		if (withScores) args ~= "WITHSCORES";
		return request("ZREVRANGE", args);
	}

	RedisReply zrevRangeByScore(string key, double min, double max, bool withScores=false) {
		string[] args = [key, to!string(min), to!string(max)];
		if (withScores) args ~= "WITHSCORES";
		return request("ZREVRANGEBYSCORE", args);
	}

	int zrevRank(string key, string member) {
		auto str = request!string("ZREVRANK", key, member);
		return str ? parse!int(str) : -1;
	}

	RedisReply zscore(string key, string member) { return request("ZSCORE", key, member); }
	//TODO: zunionstore

	/*
		TODO: Pub / Sub
	*/

	/*
		TODO: Transactions
	*/

	/*
		Connection
	*/
	void auth(string password) { m_authPassword = password; }
	T echo(T : E[], E)(T data) { return request!T("ECHO", data); }
	void ping() { request("PING"); }
	void quit() { request("QUIT"); }
	void select(size_t db_index) { m_selectedDB = db_index; }

	/*
		Server
	*/

	//TODO: BGREWRITEAOF
	//TODO: BGSAVE

	T getConfig(T : E[], E)(string parameter) { return request!T("GET CONFIG", parameter); }
	void setConfig(T : E[], E)(string parameter, T value) { request("SET CONFIG", parameter, value); }
	void configResetStat() { request("CONFIG RESETSTAT"); }
	size_t dbSize() { return request!size_t("DBSIZE"); }
	//TOOD: Debug Object
	//TODO: Debug Segfault
	void flushAll() { request("FLUSHALL"); }
	void flushDB() { request("FLUSHDB"); }
	string info() { return request!string("INFO"); }
	long lastSave() { return request!long("LASTSAVE"); }
	//TODO monitor
	void save() { request("SAVE"); }
	void shutdown() { request("SHUTDOWN"); }
	void slaveOf(string host, ushort port) { request("SLAVEOF", host, port); }
	//TODO slowlog
	//TODO sync


	T request(T = RedisReply, ARGS...)(string command, ARGS args)
	{
		auto conn = m_connections.lockConnection();
		conn.setAuth(m_authPassword);
		conn.setDB(m_selectedDB);
		auto reply = conn.request(command, args);

		static if (is(T == RedisReply)) {
			reply.m_lockedConnection = conn;
			return reply;
		} else {
			scope (exit) reply.drop();

			static if (is(T == bool)) {
				return reply.next!string[0] == '1';
			} else static if ( is(T == int) || is(T == long) || is(T == size_t) || is(T == double) ) {
				auto str = reply.next!string();
				return parse!T(str);
			} else static if (is(T == string)) {
				return reply.next!string();
			} else static if (is(T == void)) {
			} else static assert(false, "Unsupported Redis reply type: " ~ T.stringof);
		}
	}
}


final class RedisReply {
	private {
		TCPConnection m_conn;
		LockedConnection!RedisConnection m_lockedConnection;
		ubyte[] m_data;
		size_t m_length;
		size_t m_index;
		bool m_multi;
	}

	this(TCPConnection conn)
	{
		m_conn = conn;
		m_index = 0;
		m_length = 1;
		m_multi = false;

		auto ln = cast(string)m_conn.readLine();

		switch(ln[0]) {
			case '+':
				m_data = cast(ubyte[])ln[ 1 .. $ ];
				break;
			case '-':
				throw new Exception(ln[ 1 .. $ ]);
			case ':':
				m_data = cast(ubyte[])ln[ 1 .. $ ];
				break;
			case '$':
				m_data = readBulk(ln);
				break;
			case '*':
				if( ln.startsWith("*-1") ) {
					m_length = 0;
					return;
				}
				m_multi = true;
				m_length = to!size_t(ln[ 1 .. $ ]);
				break;
			default:
				assert(false, "Unknown reply type");
		}
	}

	@property bool hasNext() const { return  m_index < m_length; }

	T next(T : E[], E)()
	{
		assert( hasNext, "end of reply" );
		m_index++;
		ubyte[] ret;
		if (m_multi) {
			auto ln = cast(string)m_conn.readLine();
			ret = readBulk(ln);
		} else {
			ret = m_data;
		}
		if (m_index >= m_length) m_lockedConnection.clear();
		static if (isSomeString!T) validate(cast(T)ret);
		enforce(ret.length % E.sizeof == 0, "bulk size must be multiple of element type size");
		return cast(T)ret;
	}

	// drop the whole
	void drop()
	{
		while (hasNext) next!(ubyte[])();
	}

	private ubyte[] readBulk( string sizeLn )
	{
		if (sizeLn.startsWith("$-1")) return null;
		auto size = to!size_t( sizeLn[1 .. $] );
		auto data = new ubyte[size];
		m_conn.read(data);
		m_conn.readLine();
		return data;
	}
}


private final class RedisConnection {
	private {
		string m_host;
		ushort m_port;
		TCPConnection m_conn;
		string m_password;
		size_t m_selectedDB;
	}

	this(string host, ushort port)
	{
		m_host = host;
		m_port = port;
	}

	void setAuth(string password)
	{
		if (m_password == password) return;
		request("AUTH", password).drop();
		m_password = password;
	}

	void setDB(size_t index)
	{
		if (index == m_selectedDB) return;
		request("SELECT", index).drop();
		m_selectedDB = index;
	}

	RedisReply request(ARGS...)(string command, ARGS args)
	{
		if (!m_conn || !m_conn.connected) {
			try m_conn = connectTCP(m_host, m_port);
			catch (Exception e) {
				throw new Exception(format("Failed to connect to Redis server at %s:%s.", m_host, m_port), __FILE__, __LINE__, e);
			}
		}

		auto nargs = countArgs!ARGS();
		m_conn.write(format("*%d\r\n$%d\r\n%s\r\n", nargs + 1, command.length, command));
		writeArgs(m_conn, args);
		return new RedisReply(m_conn);
	}

	private static size_t countArgs(ARGS...)()
	{
		size_t ret;
		foreach (i, A; ARGS) {
			static if (is(A : const(string[])) || is(A : const(ubyte[][])))
				ret += countArgs!A();
			else ret++;
		}
		return ret;
	}

	private static void writeArgs(R, ARGS...)(R dst, ARGS args)
		if (isOutputRange!(R, char))
	{
		foreach (i, A; ARGS) {
			static if (is(A : const(string[])) || is(A : const(ubyte[][])))
				writeArgs(dst, args[i]);
			else static if (is(A == bool)) writeArgs(dst, args[i] ? "1" : "0");
			else static if (is(A : const(ubyte[]))) {
				dst.formattedWrite("$%s\r\n", args[i].length);
				dst.put(args[i]);
				dst.put("\r\n");
			} else static if (is(A : long) || is(A : real) || is(A == string)) {
				auto alen = formattedLength(args[i]);
				dst.formattedWrite("$%d\r\n%s\r\n", alen, args[i]);
			} else static assert(false, "Unsupported Redis argument type: " ~ T.stringof);
		}
	}

	private static size_t formattedLength(ARG)(ARG arg)
	{
		static if (is(ARG == string)) return arg.length;
		else {
			RangeCounter cnt;
			cnt.formattedWrite("%s", arg);
			return cnt.length;
		}
	}
}

private struct RangeCounter {
	import std.utf;
	size_t length = 0;
	void put(dchar ch) { length += codeLength!char(ch); }
	void put(string str) { length += str.length; }
}
