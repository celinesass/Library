from enum import Enum 


class RunCode(Enum):
    INVALID = -1
    DEBUG = 0
    DAILY = 1
    WEEKLY = 2
    MONTHLY = 3

    @classmethod
    def _missing_(cls, value):
        return RunCode.INVALID


class Permission(Enum):
    INVALID = -1
    ADMIN = 0
    EXECUTIVE = 1
    BUILD = 2
    SERVICE = 3
    PRELUDE = 4

    @classmethod
    def _missing_(cls, value):
        return Permission.INVALID


class ExitCode(Enum):
    MISSING = -1
    ERROR = 1
    MALFORMED_VST = 2
    PROCESS_KILLED = 9
    PROTECTED = 100
    UNPROTECTED = 101
    TIMEOUT = 102
    CLEANUP_ERROR = 103
    NOT_RELEVANT = 104
    QUARANTINED_1 = 105
    OUTBOUND_SECURE = 106
    INCOMPATIBLE_HOST = 126
    QUARANTINED_2 = 127
    UNEXPECTED = 256

    @classmethod
    def _missing_(cls, value):
        return ExitCode.MISSING

    @property
    def state(self):
        for k in ExitCodeGroup:
            for v in k.value: 
                if self.value == v.value:
                    return k
        return ExitCodeGroup.NONE


class ExitCodeGroup(Enum):
    NONE = [
        ExitCode.MISSING
    ]
    PROTECTED = [
        ExitCode.PROTECTED,
        ExitCode.QUARANTINED_1,
        ExitCode.QUARANTINED_2,
        ExitCode.PROCESS_KILLED,
        ExitCode.NOT_RELEVANT,
        ExitCode.OUTBOUND_SECURE
    ]
    UNPROTECTED = [
        ExitCode.UNPROTECTED
    ]
    ERROR = [
        ExitCode.ERROR,
        ExitCode.MALFORMED_VST,
        ExitCode.TIMEOUT,
        ExitCode.INCOMPATIBLE_HOST,
        ExitCode.UNEXPECTED
    ]


class DOS(Enum):
    none = 'none'
    arm64 = 'arm64'
    x86_64 = 'x86_64'
    aarch64 = 'arm64'
    amd64 = 'x86_64'
    x86 = 'x86_64'

    @classmethod
    def normalize(cls, dos: str):
        try:
            arch = dos.split('-', 1)[-1]
            return dos[:-len(arch)].lower() + cls[arch.lower()].value
        except (KeyError, IndexError) as e:
            return cls.none.value
