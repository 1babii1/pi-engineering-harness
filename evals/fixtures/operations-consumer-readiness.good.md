Before this ships: expose consumer lag (or offset-vs-latest) as a health signal, not just "process is
alive" - a stuck consumer with no lag signal looks healthy forever. Log with a correlation/trace id per
message instead of ad-hoc prints. Route poison messages to a dead-letter topic/table that is actually
visible somewhere, not swallowed in a catch block. And wire an alert on rising lag or DLQ growth with a
named on-call owner, otherwise nobody notices until a customer complains.
