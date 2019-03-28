#!/usr/local/bin/perl
#Author. Denis K. Sokolov 10/2010 IBM
#
#This is a driver for performance data graphing perl scripts
#
#I/O:
#Input: specific performance statistic descriptors and their corresponding log files
#Output: combined gnuplot graph
#
#vars:

switch($ARGV[0])
{
	case "authn_pass" {}
	case "authn_fail" {}
	case "authn_pwd_exp" {}
	case "authn_max" {}
	case "authn_total" {}
	case "authn_avg" {}
	case "authz_pass" {}
	case "authz_fail" {}
	case "certcallbackcache_hit" {}
	case "certcallbackcache_miss" {}
	case "certcallbackcache_add" {}
	case "certcallbackcache_del" {}
	case "certcallbackcache_inactive" {}
	case "certcallbackcache_lifetime" {}
	case "certcallbackcache_lru_exp" {}
	case "doccache_general_errors" {}
	case "doccache_uncachable" {}
	case "doccache_pending deletes" {}
	case "doccache_pending_size" {}
	case "doccache_misses" {}
	case "doccache_max_size" {}
	case "doccache_max_entry_size" {}
	case "doccache_default_max_age" {}
	case "doccache_size" {}
	case "doccache_count" {}
	case "doccache_hits" {}
	case "doccache_stale_hits" {}
	case "doccache_create_waits" {}
	case "doccache_cache_no_room" {}
	case "doccache_additions" {}
	case "doccache_aborts" {}
	case "doccache_deletes" {}
	case "doccache_updates" {}
	case "doccache_too_big_errors" {}
	case "doccache_mt_errors" {}
	case "drains_draining_fds" {}
	case "drains_failed_closes" {}
	case "drains_failed selects" {}
	case "drains_fds_closed_hiwat" {}
	case "drains_fds_closed_flood" {}
	case "drains_timed_out_fds" {}
	case "drains_idle_awakenings" {}
	case "drains_bytes_drained" {}
	case "drains_drained_fds" {}
	case "drains_avg_bytes_drained" {}
	case "http_reqs" {}
	case "http_max_worker" {}
	case "http_avg_worker" {}
	case "http_total_worker" {}
	case "http_max_webseal" {}
	case "http_avg_webseal" {}
	case "http_total_webseal" {}
	case "https_reqs" {}
	case "https_max_worker" {}
	case "https_avg_worker" {}
	case "https_total_worker" {}
	case "https_max_webseal" {}
	case "https_avg_webseal" {}
	case "https_total_webseal" {}
	case "jct_reqs" {}
	case "jct_max" {}
	case "jct_avg" {}
	case "jct_total" {}
	case "jmt_hits" {}
	case "sescache_hit" {}
	case "sescache_miss" {}
	case "sescache_add" {}
	case "sescache_del" {}
	case "sescache_inactive" {}
	case "sescache_lifetime" {}
	case "sescache_lru_exp" {}
	case "threads_active" {}
	case "threads_total" {}
	case "threads_default_active" {}
	case "threads_default_total" {}
	case "usersessidcache_hit" {}
	case "usersessidcache_miss" {}
	case "usersessidcache_add" {}
	case "usersessidcache_del" {}
	case "usersessidcache_inactive" {}
	case "usersessidcache_lifetime" {}
	case "usersessidcache_lru_exp" {}
	case "vhj_reqs" {}
	case "vhj_max" {}
	case "vhj_avg" {}
	case "vhj_total" {}
}