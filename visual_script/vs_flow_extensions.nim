
import vs_network, vs_host

type IfVSHost* = ref object of VSHost
    i0*: VSPort[bool]
    falseFlow*: seq[VSHost]

proc newIfVSHost*(): IfVSHost =
    result.new()
    result.name = "if"
    result.flow = @[]
    result.falseFlow = @[]
    result.i0 = newVSPort("condition", bool, VSPortKind.Input)

method invokeFlow*(host: IfVSHost) =
    if host.i0.read():
        for h in host.flow:
            h.invokeFlow()
    else:
        for h in host.falseFlow:
            h.invokeFlow()

method getPort*(vs: IfVSHost; name: string, clone: bool = false, cloneAs: VSPortKind = VSPortKind.Output): Variant =
    if name == "i0":
        return newVariant(if clone: vs.i0.clone(cloneAs) else: vs.i0)

method connect*(vs: IfVSHost; port: string; port2: Variant) =
    if port == "i0":
        vs.i0.connect(port2)

method metadata*(vs: IfVSHost): VSHostMeta =
    return ("IfVSHost", "IfVSHost", @[("condition", "bool", "")], @[("false", "VSFlow", "")])

putHostToRegistry(IfVSHost, proc(): VSHost = newIfVSHost())


type IfElifVSHost* = ref object of VSHost
    ports*: seq[VSPort[bool]]
    trueFlow*: seq[seq[VSHost]]
    falseFlow*: seq[VSHost]

proc newIfElifVSHost*(): IfElifVSHost =
    result.new()
    result.name = "if"
    result.trueFlow = @[]
    result.falseFlow = @[]
    result.ports = @[]

method invokeFlow*(vs: IfElifVSHost) =
    for i, b in vs.ports:
        if b.read():
            for h in vs.trueFlow[i]:
                h.invokeFlow()
                return

    for h in vs.falseFlow:
        h.invokeFlow()

proc setLen*(vs: IfElifVSHost, len: Natural) =
    if vs.ports.len > len:
        vs.ports.setLen(len)
        vs.trueFlow.setLen(len)
    else:
        let oldLen = vs.ports.len
        for i in oldLen ..< len:
            vs.ports.add(newVSPort("condition" & $i, bool, VSPortKind.Input))
            vs.trueFlow.add(newSeq[VSHost]())

proc port*(vs: IfElifVSHost, ind: Natural): VSPort[bool] =
    vs.ports[ind]

putHostToRegistry(IfElifVSHost, proc(): VSHost = newIfElifVSHost())


type WhileVSHost* = ref object of VSHost
    i0*: VSPort[bool]
    endFlow*: seq[VSHost]

proc newWhileVSHost*(): WhileVSHost =
    result.new()
    result.name = "while"
    result.flow = @[]
    result.endFlow = @[]
    result.i0 = newVSPort("condition", bool, VSPortKind.Input)

method invokeFlow*(host: WhileVSHost) =
    while host.i0.read():
        for h in host.flow:
            h.invokeFlow()
    for h in host.endFlow:
        h.invokeFlow()

putHostToRegistry(WhileVSHost, proc(): VSHost = newWhileVSHost())

registerFlowNetworkExtension('+') do(net: VSNetwork, source: string, start: var int, hostId1, hostId2, port1Name, port2Name: var string, localHostMapper: Table[string, int]):
    start += source.parseUntil(hostId2, '\n', start + 1) + 2

    let host1 = net.hosts[localHostMapper[hostId1]]
    let host2 = net.hosts[localHostMapper[hostId2]]

    host1.IfVSHost.flow.add(host2)

registerFlowNetworkExtension('-') do(net: VSNetwork, source: string, start: var int, hostId1, hostId2, port1Name, port2Name: var string, localHostMapper: Table[string, int]):
    start += source.parseUntil(hostId2, '\n', start + 1) + 2

    let host1 = net.hosts[localHostMapper[hostId1]]
    let host2 = net.hosts[localHostMapper[hostId2]]

    host1.IfVSHost.falseFlow.add(host2)