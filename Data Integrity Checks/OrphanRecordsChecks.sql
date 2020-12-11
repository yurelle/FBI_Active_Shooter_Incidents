-- Check for any incident records that do not have at least one incidentState record
select *
from incident
where id not in (
    select distinct incidentId
    from incidentState
);

-- Check for any incidentState records that do not have at least one incident record
select *
from incidentState
where incidentId not in (
    select distinct id
    from incident
);

-- Check for any incident records that do not have at least one shooter record
select *
from incident
where id not in (
    select distinct incidentId
    from shooter
);

-- Check for any shooter records that do not have at least one incident record
select *
from shooter
where incidentId not in (
    select distinct id
    from incident
);

-- Check for any stateIncident records that do not have a valid state record
select *
from incidentState
where stateId not in (
    select distinct id
    from stateLookup
);
