# frozen_string_literal: true

# Canned cgminer API responses used by the integration specs and the
# `script/fake_cgminer` manual sandbox.
#
# Every fixture is grounded in cgminer's actual wire format:
#
#   - Message codes (MSG_SUMM=11, MSG_DEVS=9, MSG_POOL=7, MSG_ADDPOOL=55,
#     MSG_INVCMD=14, MSG_ACCDENY=45, MSG_ACCOK=46, MSG_VERSION=22) come
#     from the `codes[]` table in cgminer/api.c.
#   - Response envelope keys are uppercase (STATUS, Code, Msg, When,
#     Description), command-data keys are uppercase (SUMMARY, DEVS,
#     POOLS, ...), and `id` is lowercase. This matches what
#     Miner#check_status reads out of the parsed response.
#
# Where a fixture deliberately exercises a gem code path (the `}{`
# malformed-multi-command repair, the \uXXXX control-byte escape,
# the parameter-escape assertion), that intent is noted on the
# fixture itself.
module CgminerFixtures
  WHEN = 1_700_000_000

  # Single-result success. Used by the summary integration test.
  # MSG_SUMM = 11, Msg = "Summary".
  SUMMARY = <<~JSON.tr("\n", '')
    {"STATUS":[{"STATUS":"S","When":#{WHEN},"Code":11,"Msg":"Summary","Description":"cgminer 4.11.1"}],"SUMMARY":[{"Elapsed":12345,"MHS av":56789.12,"Found Blocks":0,"Getworks":42,"Accepted":100,"Rejected":1,"Hardware Errors":0,"Utility":4.87,"Discarded":8,"Stale":0,"Get Failures":0,"Local Work":1024,"Remote Failures":0,"Network Blocks":1,"Total MH":702345.67,"Work Utility":4.85,"Difficulty Accepted":6400.0,"Difficulty Rejected":64.0,"Difficulty Stale":0.0,"Best Share":123456789,"Device Hardware%":0.0000,"Device Rejected%":0.9901,"Pool Rejected%":0.9901,"Pool Stale%":0.0000,"Last getwork":#{WHEN}}],"id":1}
  JSON

  # Array-result success. Used by the devs integration test.
  # MSG_DEVS = 9 (the "%d ASC(s) - %d PGA(s)" variant is close enough).
  DEVS = <<~JSON.tr("\n", '')
    {"STATUS":[{"STATUS":"S","When":#{WHEN},"Code":9,"Msg":"2 ASC(s)","Description":"cgminer 4.11.1"}],"DEVS":[{"ASC":0,"Name":"BTM","ID":0,"Enabled":"Y","Status":"Alive","Temperature":65.0,"MHS av":14000000.0,"MHS 5s":14000100.0,"Accepted":50,"Rejected":0,"Hardware Errors":0,"Utility":2.44,"Last Share Pool":0,"Last Share Time":#{WHEN},"Total MH":175432.1,"Diff1 Work":0,"Difficulty Accepted":3200.0,"Difficulty Rejected":0.0,"Last Share Difficulty":64.0,"Last Valid Work":#{WHEN},"Device Hardware%":0.0,"Device Rejected%":0.0},{"ASC":1,"Name":"BTM","ID":1,"Enabled":"Y","Status":"Alive","Temperature":64.5,"MHS av":14000000.0,"MHS 5s":13999900.0,"Accepted":49,"Rejected":1,"Hardware Errors":0,"Utility":2.40,"Last Share Pool":0,"Last Share Time":#{WHEN},"Total MH":175400.0,"Diff1 Work":0,"Difficulty Accepted":3136.0,"Difficulty Rejected":64.0,"Last Share Difficulty":64.0,"Last Valid Work":#{WHEN},"Device Hardware%":0.0,"Device Rejected%":2.0}],"id":1}
  JSON

  # Pools listing. Used as the happy-path pools fixture.
  # MSG_POOL = 7, Msg = "%d Pool(s)".
  POOLS = <<~JSON.tr("\n", '')
    {"STATUS":[{"STATUS":"S","When":#{WHEN},"Code":7,"Msg":"1 Pool(s)","Description":"cgminer 4.11.1"}],"POOLS":[{"POOL":0,"URL":"stratum+tcp://example.pool:3333","Status":"Alive","Priority":0,"Quota":1,"Long Poll":"N","Getworks":10,"Accepted":100,"Rejected":1,"Works":500,"Discarded":5,"Stale":0,"Get Failures":0,"Remote Failures":0,"User":"worker1","Last Share Time":#{WHEN},"Diff1 Shares":0,"Proxy Type":"","Proxy":"","Difficulty Accepted":6400.0,"Difficulty Rejected":64.0,"Difficulty Stale":0.0,"Last Share Difficulty":64.0,"Has Stratum":true,"Stratum Active":true,"Stratum URL":"example.pool","Has GBT":false,"Best Share":123456789,"Pool Rejected%":0.9901,"Pool Stale%":0.0000}],"id":1}
  JSON

  # Multi-command response. Modern cgminer emits a single top-level
  # object with one key per sub-command, each value an array whose
  # first element has its own STATUS block. This matches the shape
  # Miner#perform_request expects when the command name contains
  # '+' — it iterates data with each_pair and calls check_status on
  # each response.first.
  #
  # Note: the gem also has gsub! repair logic for a `}{` malformed
  # variant, but that repair does not actually produce valid JSON
  # from any format I can reproduce, and may be legacy defensive
  # code for a cgminer version that no longer exists. If the repair
  # is ever confirmed to fire on real traffic, add a targeted unit
  # test at the perform_request layer rather than here.
  SUMMARY_PLUS_POOLS = <<~JSON.tr("\n", '')
    {"summary":[{"STATUS":[{"STATUS":"S","When":#{WHEN},"Code":11,"Msg":"Summary","Description":"cgminer 4.11.1"}],"SUMMARY":[{"Elapsed":1,"MHS av":1.0}]}],"pools":[{"STATUS":[{"STATUS":"S","When":#{WHEN},"Code":7,"Msg":"1 Pool(s)","Description":"cgminer 4.11.1"}],"POOLS":[{"POOL":0,"URL":"stratum+tcp://example.pool:3333","Status":"Alive"}]}],"id":1}
  JSON

  # Response containing a 0x01 byte inside a string value. The gem
  # re-escapes bytes below 0x20 as \uXXXX before JSON.parse so this
  # fixture exercises the control-byte escape path in
  # Miner#perform_request. Real cgminer can emit control bytes in
  # user-supplied pool names and worker IDs.
  POOLS_WITH_CONTROL_BYTE = (+<<~JSON.tr("\n", '')).b
    {"STATUS":[{"STATUS":"S","When":#{WHEN},"Code":7,"Msg":"1 Pool(s)","Description":"cgminer 4.11.1"}],"POOLS":[{"POOL":0,"URL":"\x01weird","Status":"Alive","User":"worker1"}],"id":1}
  JSON

  # Successful addpool. MSG_ADDPOOL = 55.
  ADDPOOL_OK = <<~JSON.tr("\n", '')
    {"STATUS":[{"STATUS":"S","When":#{WHEN},"Code":55,"Msg":"Added pool 1: 'stratum+tcp://x:1'","Description":"cgminer 4.11.1"}],"id":1}
  JSON

  # Successful privileged access check. MSG_ACCOK = 46.
  PRIVILEGED_OK = <<~JSON.tr("\n", '')
    {"STATUS":[{"STATUS":"S","When":#{WHEN},"Code":46,"Msg":"Privileged access OK","Description":"cgminer 4.11.1"}],"id":1}
  JSON

  # Privileged access denied. MSG_ACCDENY = 45. Same envelope format
  # as a success but with STATUS=E. check_status will raise ApiError
  # with "45: Access denied".
  PRIVILEGED_DENIED = <<~JSON.tr("\n", '')
    {"STATUS":[{"STATUS":"E","When":#{WHEN},"Code":45,"Msg":"Access denied","Description":"cgminer 4.11.1"}],"id":1}
  JSON

  # Default map used by FakeCgminer when a test doesn't supply one.
  DEFAULT = {
    'summary' => SUMMARY,
    'devs' => DEVS,
    'pools' => POOLS,
    'summary+pools' => SUMMARY_PLUS_POOLS,
    'addpool' => ADDPOOL_OK,
    'privileged' => PRIVILEGED_OK
  }.freeze

  # Synthesized "unknown command" response. Real cgminer emits this
  # with MSG_INVCMD = 14 when it receives a command it doesn't know.
  def self.invalid_command(name)
    <<~JSON.tr("\n", '')
      {"STATUS":[{"STATUS":"E","When":#{WHEN},"Code":14,"Msg":"Invalid command","Description":"cgminer 4.11.1 (#{name})"}],"id":1}
    JSON
  end
end
