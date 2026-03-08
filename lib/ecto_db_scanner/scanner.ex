defmodule EctoDBScanner.Scanner do
  use Reactor

  input :repo

  step :tables, EctoDBScanner.Steps.QueryTables do
    argument :repo, input(:repo)
  end

  step :columns, EctoDBScanner.Steps.QueryColumns do
    argument :repo, input(:repo)
  end

  step :pg_enums, EctoDBScanner.Steps.QueryPGEnums do
    argument :repo, input(:repo)
  end

  step :constraints, EctoDBScanner.Steps.QueryConstraints do
    argument :repo, input(:repo)
  end

  step :sizes, EctoDBScanner.Steps.QuerySizes do
    argument :repo, input(:repo)
  end

  step :indexes, EctoDBScanner.Steps.QueryIndexes do
    argument :repo, input(:repo)
  end

  step :sequences, EctoDBScanner.Steps.QuerySequences do
    argument :repo, input(:repo)
  end

  step :detect_enums, EctoDBScanner.Steps.DetectEnums do
    argument :repo, input(:repo)
    argument :tables, result(:tables)
    argument :columns, result(:columns)
    argument :pg_enums, result(:pg_enums)
  end

  step :assemble, EctoDBScanner.Steps.AssembleResults do
    argument :tables, result(:tables)
    argument :columns, result(:columns)
    argument :enum_info, result(:detect_enums)
    argument :constraints, result(:constraints)
    argument :sizes, result(:sizes)
    argument :indexes, result(:indexes)
    argument :sequences, result(:sequences)
  end

  return :assemble
end
