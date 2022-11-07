// types
import type { ReactNode } from 'react';

interface Option {
  label: ReactNode;
  value: string;
}

type Props = {
  legend?: ReactNode;
  onChange: (selected: Option) => void;
  options: Option[];
  selected?: Option | null;
  styles?: string[];
  tile?: boolean;
};

export default function RadioButtons({
  legend,
  onChange,
  options,
  selected = null,
  styles = [],
  tile = false,
}: Props) {
  return (
    <fieldset className={`usa-fieldset ${styles.join(' ')}`}>
      {legend && <legend className="usa-legend">{legend}</legend>}
      {options.map((option, i) => (
        <div key={i} className="usa-radio">
          <input
            className={`usa-radio__input ${tile && 'usa-radio__input--tile'}`}
            id={`radio-${option.value}-${i}`}
            type="radio"
            value={option.value}
            checked={option.value === selected?.value}
            onChange={(_ev) => onChange(option)}
          />
          <label
            className="usa-radio__label"
            htmlFor={`radio-${option.value}-${i}`}
          >
            {option.label}
          </label>
        </div>
      ))}
    </fieldset>
  );
}